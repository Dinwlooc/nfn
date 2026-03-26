extends RefCounted
class_name StageManager

signal stage_completed()
signal stage_rolled_back(old_stage: Stage, new_stage: Stage)
signal temp_stages_cleared()
signal round_ended()
signal stage_changed(old_stage: Stage, new_stage: Stage)
signal temp_stage_started(temp_stage: Stage)
signal round_completed()

var main_stages: Array[Stage] = []
var pending_temp_stage_stack: Array[Stage] = []   # 待开始的临时阶段栈（后进先出）
var timer: GameTimer
var game_state: GameState
var current_main_stage_index: int = -1
var stage_context: StageContext

static var MAIN_STAGES: Array[Script] = [
	StageStart,
	StageDraw,
	StageMain,
	StageDiscard,
	StageEnd
]

func _init(p_game_state: GameState) -> void:
	game_state = p_game_state
	# 创建阶段上下文
	stage_context = StageContext.new()
	# 注入到 GameState
	game_state.stage_context = stage_context

	main_stages.resize(MAIN_STAGES.size())
	for i in MAIN_STAGES.size():
		main_stages[i] = MAIN_STAGES[i].new()
		connect_stage_to_manager(main_stages[i])

func connect_stage_to_manager(new_stage: Stage) -> void:
	new_stage.stage_ended.connect(_on_stage_ended)
	new_stage.request_reset_timer.connect(_on_stage_reset_timer_requested)

func _disconnect_stage_signals(stage: Stage) -> void:
	if stage.stage_ended.is_connected(_on_stage_ended):
		stage.stage_ended.disconnect(_on_stage_ended)
	if stage.request_reset_timer.is_connected(_on_stage_reset_timer_requested):
		stage.request_reset_timer.disconnect(_on_stage_reset_timer_requested)

func handle_validated_request(request: OperationRequest) -> void:
	stage_context.current_stage.process_operation_request(request, game_state)

func set_timer(_timer: GameTimer) -> void:
	if timer:
		timer.timeout.disconnect(_on_timer_timeout)
	timer = _timer
	timer.timeout.connect(_on_timer_timeout)

func complete_current_stage() -> void:
	var cur = stage_context.current_stage
	if cur and not cur.is_ended:
		cur.end_stage(game_state)

func complete_all_temp_stages() -> void:
	if stage_context.temp_stage_stack.is_empty():
		return
	while not stage_context.temp_stage_stack.is_empty():
		var stage = stage_context.temp_stage_stack.pop_back()
		if not stage.is_ended:
			stage.end_stage_effect(game_state)
	# 清空临时阶段栈，保留主阶段信息
	# 原逻辑中还会清空 game_state.current_stage_stack，现在由 GameState 通过 context 获取
	temp_stages_cleared.emit()

## 请求插入临时阶段（若处理器繁忙则进入待处理栈，否则立即开始）
func start_temp_stage(temp_stage: Stage) -> void:
	if game_state._process_active:
		pending_temp_stage_stack.append(temp_stage)
		return
	_start_immediate(temp_stage)

## 立即开始临时阶段（内部方法）
func _start_immediate(temp_stage: Stage) -> void:
	var cur = stage_context.current_stage
	if cur:
		cur.pause(game_state)
	temp_stage.is_temporary = true
	connect_stage_to_manager(temp_stage)
	# 将当前阶段压入暂停栈
	stage_context.temp_stage_stack.append(cur)
	_transition_to(temp_stage)
	temp_stage_started.emit(temp_stage)

## 命令处理器空闲时调用（由 System 连接 all_completed 信号）
func _on_command_processor_idle() -> void:
	if not pending_temp_stage_stack.is_empty():
		var next_stage = pending_temp_stage_stack.pop_back()
		_start_immediate(next_stage)

func end_round() -> void:
	if timer:
		timer.stop()
	if stage_context.current_stage and not stage_context.current_stage.is_ended:
		stage_context.current_stage.end_stage_effect(game_state)
	# 清空所有栈
	stage_context.temp_stage_stack.clear()
	pending_temp_stage_stack.clear()
	stage_context.current_main_stage_name = &""
	stage_context.current_player_id = 0
	stage_context.current_stage = null
	current_main_stage_index = -1
	round_ended.emit()
	round_completed.emit()

func _transition_to(new_stage: Stage) -> void:
	if not new_stage:
		return
	var old_stage: Stage = stage_context.current_stage
	if old_stage:
		_disconnect_stage_signals(old_stage)
	stage_context.current_stage = new_stage
	if not new_stage.is_temporary:
		stage_context.current_main_stage_name = new_stage.stage_name
		# 主阶段切换时清空临时阶段栈
		complete_all_temp_stages()
	else:
		pass
	if new_stage.time_limit > 0.0:
		timer.start(new_stage.time_limit)
	else:
		timer.stop()
	if new_stage.is_paused:
		new_stage.call_deferred(&"resume", game_state)
		stage_rolled_back.emit(old_stage, new_stage)
	else:
		new_stage.call_deferred(&"enter", game_state)
		stage_changed.emit(old_stage, new_stage)

func _rollback_to_previous_stage() -> void:
	if stage_context.temp_stage_stack.is_empty():
		push_error("没有可回退的阶段")
		return
	var previous_stage = stage_context.temp_stage_stack.pop_back()
	if not previous_stage:
		push_error("回退的阶段无效")
		return
	if stage_context.current_stage and not stage_context.current_stage.is_ended:
		stage_context.current_stage.end_stage(game_state)
	previous_stage.resume(game_state)
	_transition_to(previous_stage)

func _advance_to_next_main_stage() -> void:
	current_main_stage_index += 1
	if current_main_stage_index >= main_stages.size():
		end_round()
		return
	_transition_to(main_stages[current_main_stage_index])

func _on_stage_ended(ended_stage: Stage) -> void:
	if ended_stage != stage_context.current_stage:
		return
	if timer:
		timer.stop()
	stage_completed.emit()
	if ended_stage.is_temporary:
		if stage_context.temp_stage_stack.is_empty():
			_advance_to_next_main_stage()
		else:
			_rollback_to_previous_stage()
	else:
		_advance_to_next_main_stage()

func _on_timer_timeout() -> void:
	var cur = stage_context.current_stage
	if cur and not cur.is_ended:
		cur.timeout(game_state)

func start_round(player_id: int = 0) -> void:
	current_main_stage_index = 0
	stage_context.current_player_id = player_id
	stage_context.temp_stage_stack.clear()
	pending_temp_stage_stack.clear()
	_transition_to(main_stages[current_main_stage_index])

func get_current_stage_enum() -> int:
	return current_main_stage_index

func _on_stage_reset_timer_requested(new_time_limit: float) -> void:
	var cur = stage_context.current_stage
	if timer and cur and not cur.is_ended:
		timer.start(new_time_limit)
