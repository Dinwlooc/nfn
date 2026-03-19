extends RefCounted
class_name StageManager

# 新增信号
signal stage_completed()
signal stage_rolled_back(old_stage: Stage, new_stage: Stage)
signal temp_stages_cleared()
signal round_ended()
signal stage_changed(old_stage: Stage, new_stage: Stage)
signal temp_stage_started(temp_stage: Stage)
signal round_completed()

# 主阶段顺序数组
var main_stages: Array[Stage] = []
var current_stage: Stage = null
var temp_stage_stack: Array[Stage] = []          # 正在执行的临时阶段栈（已暂停的父阶段）
var pending_temp_stage_stack: Array[Stage] = []  # 待开始的临时阶段栈（后进先出）
var timer: GameTimer
var game_state: GameState
var current_main_stage_index: int = -1
var current_player_id: int = 0
var modifier_container: ModifierContainer

static var MAIN_STAGES: Array[Script] = [
	StageStart,
	StageDraw,
	StageMain,
	StageDiscard,
	StageEnd
]

func _init(p_game_state: GameState) -> void:
	game_state = p_game_state
	main_stages.resize(MAIN_STAGES.size())
	for i in MAIN_STAGES.size():
		main_stages[i] = MAIN_STAGES[i].new(game_state)
		connect_stage_to_manager(main_stages[i])

func connect_stage_to_manager(new_stage: Stage) -> void:
	new_stage.stage_ended.connect(_on_stage_ended)

func set_modifier_container(container: ModifierContainer) -> void:
	modifier_container = container

func handle_validated_request(request: OperationRequest) -> void:
	current_stage.process_operation_request(request)

func set_timer(_timer: GameTimer) -> void:
	if timer:
		timer.timeout.disconnect(_on_timer_timeout)
	timer = _timer
	timer.timeout.connect(_on_timer_timeout)

func complete_current_stage() -> void:
	if current_stage and not current_stage.is_ended:
		current_stage.end_stage()

func complete_all_temp_stages() -> void:
	if temp_stage_stack.is_empty():
		return
	while not temp_stage_stack.is_empty():
		var stage = temp_stage_stack.pop_back()
		if not stage.is_ended:
			stage.end_stage_effect()
	if game_state.current_stage_stack.size() > 1:
		var main_stage_name = game_state.current_stage_stack[0]
		game_state.current_stage_stack = [main_stage_name]
	temp_stages_cleared.emit()

## 请求插入临时阶段（若处理器繁忙则进入待处理栈，否则立即开始）
func start_temp_stage(temp_stage: Stage) -> void:
	# 根据命令处理器是否繁忙决定立即开始或暂存
	if game_state._process_active:
		pending_temp_stage_stack.append(temp_stage)
	else:
		_start_immediate(temp_stage)

## 立即开始临时阶段（内部方法）
func _start_immediate(temp_stage: Stage) -> void:
	if current_stage:
		current_stage.pause()
	temp_stage.is_temporary = true
	connect_stage_to_manager(temp_stage)
	# 将当前阶段推入执行栈（暂停）
	temp_stage_stack.append(current_stage)
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
	if current_stage and not current_stage.is_ended:
		current_stage.end_stage_effect()
	# 清空所有栈
	temp_stage_stack.clear()
	pending_temp_stage_stack.clear()
	current_main_stage_index = -1
	current_stage = null
	round_ended.emit()
	round_completed.emit()

func _transition_to(new_stage: Stage) -> void:
	if not new_stage:
		return
	var old_stage: Stage = current_stage
	current_stage = new_stage
	if new_stage.is_temporary:
		game_state.current_stage_stack.append(new_stage.stage_name)
	else:
		game_state.current_stage_stack = [new_stage.stage_name]
		complete_all_temp_stages()
	if new_stage.time_limit > 0.0:
		timer.start(new_stage.time_limit)
	else:
		timer.stop()
	if new_stage.is_paused:
		new_stage.call_deferred(&"resume")
		stage_rolled_back.emit(old_stage, new_stage)
	else:
		new_stage.call_deferred(&"enter")
		stage_changed.emit(old_stage, new_stage)

func _rollback_to_previous_stage() -> void:
	if temp_stage_stack.is_empty():
		push_error("没有可回退的阶段")
		return
	var previous_stage = temp_stage_stack.pop_back()
	if not previous_stage:
		push_error("回退的阶段无效")
		return
	if current_stage:
		current_stage.end_stage_effect()
	previous_stage.resume()
	_transition_to(previous_stage)

func _advance_to_next_main_stage() -> void:
	current_main_stage_index += 1
	if current_main_stage_index >= main_stages.size():
		end_round()
		return
	_transition_to(main_stages[current_main_stage_index])

func _on_stage_ended(ended_stage: Stage) -> void:
	if ended_stage != current_stage:
		return
	if timer:
		timer.stop()
	stage_completed.emit()
	if ended_stage.is_temporary:
		if temp_stage_stack.is_empty():
			_advance_to_next_main_stage()
		else:
			_rollback_to_previous_stage()
	else:
		_advance_to_next_main_stage()

func _on_timer_timeout() -> void:
	if current_stage and not current_stage.is_ended:
		complete_current_stage()

func start_round(player_id: int = 0) -> void:
	current_main_stage_index = 0
	current_player_id = player_id
	temp_stage_stack.clear()
	pending_temp_stage_stack.clear()   # 新回合清空待处理栈
	_transition_to(main_stages[current_main_stage_index])

func get_current_stage_enum() -> int:
	return current_main_stage_index
