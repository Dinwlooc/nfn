extends RefCounted
class_name StageManager

var main_stages: Array[Stage] = []
var pending_temp_stage_stack: Array[Stage] = []
var timer: GameTimer
var current_main_stage_index: int = -1

# 原 StageContext 成员
var current_stage: Stage = null
var temp_stage_stack: Array[Stage] = []
var current_main_stage_name: StringName = &""
var current_player_id: int = 0

# 信号
signal stage_completed(stage: Stage)
signal stage_rolled_back(old_stage: Stage, new_stage: Stage)
signal temp_stages_cleared()
signal round_ended()
signal stage_changed(old_stage: Stage, new_stage: Stage)
signal temp_stage_started(temp_stage: Stage)
signal round_completed()
signal stage_entered(stage: Stage)

static var MAIN_STAGE_NAMES: PackedStringArray = [
	&"Start",
	&"Draw",
	&"Main",
	&"Discard",
	&"End"
]

static var MAIN_STAGES_SCRIPTS: Array[Script] = [
	StageStart,
	StageDraw,
	StageMain,
	StageDiscard,
	StageEnd
]

func _init():
	main_stages.resize(MAIN_STAGES_SCRIPTS.size())
	for i in MAIN_STAGES_SCRIPTS.size():
		main_stages[i] = MAIN_STAGES_SCRIPTS[i].new()

func connect_stage_to_manager(new_stage: Stage, game_state: GameState) -> void:
	if not new_stage.stage_ended.is_connected(_on_stage_ended):
		new_stage.stage_ended.connect(_on_stage_ended.bind(game_state))
	if not new_stage.request_reset_timer.is_connected(_on_stage_reset_timer_requested):
		new_stage.request_reset_timer.connect(_on_stage_reset_timer_requested.bind(game_state))

func _disconnect_stage_signals(stage: Stage, game_state: GameState) -> void:
	if stage.stage_ended.is_connected(_on_stage_ended):
		stage.stage_ended.disconnect(_on_stage_ended)
	if stage.request_reset_timer.is_connected(_on_stage_reset_timer_requested):
		stage.request_reset_timer.disconnect(_on_stage_reset_timer_requested)

func set_timer(_timer: GameTimer) -> void:
	timer = _timer
	# 不再自动连接 timeout 信号，由外部（System）负责连接并传入 game_state

func handle_validated_request(request: OperationRequest, game_state: GameState) -> void:
	if not current_stage:
		push_error("StageManager: 当前阶段为空，无法处理操作请求")
		return
	current_stage.process_operation_request(request, game_state)

func complete_current_stage(game_state: GameState) -> void:
	if current_stage and not current_stage.is_ended:
		current_stage.end_stage(game_state)

func complete_all_temp_stages(game_state: GameState) -> void:
	if temp_stage_stack.is_empty():
		return
	while not temp_stage_stack.is_empty():
		var stage = temp_stage_stack.pop_back()
		if not stage.is_ended:
			stage.end_stage(game_state)
	temp_stages_cleared.emit()

func start_temp_stage(temp_stage: Stage, game_state: GameState) -> void:
	if game_state._process_active:
		pending_temp_stage_stack.append(temp_stage)
		return
	_start_immediate(temp_stage, game_state)

func _start_immediate(temp_stage: Stage, game_state: GameState) -> void:
	var cur = current_stage
	if cur:
		cur.pause(game_state)
	temp_stage.is_temporary = true
	connect_stage_to_manager(temp_stage, game_state)
	temp_stage_stack.append(cur)
	_transition_to(temp_stage, game_state)
	temp_stage_started.emit(temp_stage)

func on_command_processor_idle(game_state: GameState) -> void:
	if not pending_temp_stage_stack.is_empty():
		var next_stage:Stage = pending_temp_stage_stack.pop_back()
		_start_immediate(next_stage, game_state)

func end_round(game_state: GameState) -> void:
	if timer:
		timer.stop()
	if current_stage and not current_stage.is_ended:
		current_stage.end_stage(game_state)
	temp_stage_stack.clear()
	pending_temp_stage_stack.clear()
	current_main_stage_name = &""
	current_player_id = 0
	current_stage = null
	current_main_stage_index = -1
	#GlobalConsole._print(["StageManager:回合结束。"])
	round_ended.emit()
	round_completed.emit()

## 启动阶段：启动计时器，调用 enter/resume，发出 stage_entered 信号
func _start_stage(stage: Stage, game_state: GameState) -> void:
	if stage.time_limit > 0.0:
		timer.start(stage.time_limit)
	else:
		timer.stop()
	if stage.is_paused:
		stage.resume(game_state)
	else:
		stage.enter(game_state)
		stage_entered.emit(stage)

func _transition_to(new_stage: Stage, game_state: GameState) -> void:
	if not new_stage:
		return
	var old_stage = current_stage
	if old_stage:
		_disconnect_stage_signals(old_stage, game_state)
	current_stage = new_stage
	if not new_stage.is_temporary:
		current_main_stage_name = new_stage.stage_name
		complete_all_temp_stages(game_state)
	# 计时器启动延迟到 _start_stage，此处不再启动
	connect_stage_to_manager(new_stage, game_state)
	# 发出阶段变更信号（阶段引用已更新）
	stage_changed.emit(old_stage, new_stage)
	# 检查是否还有命令未完成，决定立即启动或延迟启动
	if game_state._process_active:
		# 使用一次性信号连接，在命令完成后启动阶段
		var stage_to_start = new_stage
		game_state.all_commands_completed.connect(
			func():
			if current_stage == stage_to_start:
				_start_stage(stage_to_start, game_state)
			, CONNECT_ONE_SHOT
		)
	else:
		_start_stage(new_stage, game_state)

func _rollback_to_previous_stage(game_state: GameState) -> void:
	if temp_stage_stack.is_empty():
		push_error("没有可回退的阶段")
		return
	var previous_stage:Stage = temp_stage_stack.pop_back()
	if not previous_stage:
		push_error("回退的阶段无效")
		return
	if current_stage and not current_stage.is_ended:
		current_stage.end_stage(game_state)
	_transition_to(previous_stage, game_state)

func _advance_to_next_main_stage(game_state: GameState) -> void:
	current_main_stage_index += 1
	if current_main_stage_index >= main_stages.size():
		#GlobalConsole._print(["StageManager:自动推进回合。"])
		game_state.queue_behavior(NewRoundCommand.new(current_player_id))
		return
	_transition_to(main_stages[current_main_stage_index], game_state)

func _on_stage_ended(ended_stage: Stage, game_state: GameState) -> void:
	if ended_stage != current_stage:
		return
	if timer:
		timer.stop()
	stage_completed.emit(ended_stage)
	if ended_stage.is_temporary:
		game_state.queue_behavior(RollbackStageCommand.new(current_player_id, ended_stage))
		#GlobalConsole._print(["StageManager:自动回退阶段。"])
	else:
		game_state.queue_behavior(SwitchMainStageCommand.new(current_player_id))
		#GlobalConsole._print(["StageManager:自动推进阶段。"])

## 由外部调用的超时处理（System 需连接 timer.timeout 到此方法，并绑定 game_state）
func on_timer_timeout(game_state: GameState) -> void:
	if current_stage and not current_stage.is_ended:
		current_stage.timeout(game_state)

func _on_stage_reset_timer_requested(new_time_limit: float, game_state: GameState) -> void:
	if timer and current_stage and not current_stage.is_ended:
		timer.start(new_time_limit)

func start_round(player_id: int, game_state: GameState) -> void:
	end_round(game_state)
	current_main_stage_index = 0
	current_player_id = player_id
	temp_stage_stack.clear()
	pending_temp_stage_stack.clear()
	_transition_to(main_stages[current_main_stage_index], game_state)

func get_current_stage_enum() -> int:
	return current_main_stage_index

func switch_to_main_stage(game_state: GameState, skipped_stage_count:int = 0) -> void:
	current_main_stage_index += skipped_stage_count
	_advance_to_next_main_stage(game_state)

func rollback_stage(game_state: GameState, player_id: int) -> void:
	if player_id != current_player_id:
		return
	_rollback_to_previous_stage(game_state)

## 检查是否存在指定名称的阶段（包括当前阶段、临时阶段栈、等待队列）
func has_stage_with_name(stage_name: StringName) -> bool:
	if current_stage and current_stage.stage_name == stage_name:
		return true
	for stage in temp_stage_stack:
		if stage.stage_name == stage_name:
			return true
	for stage in pending_temp_stage_stack:
		if stage.stage_name == stage_name:
			return true
	return false
