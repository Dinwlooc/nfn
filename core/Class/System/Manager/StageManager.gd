## 阶段管理器：管理主阶段与临时阶段的生命周期
extends RefCounted
class_name StageManager

## 主阶段列表（按顺序循环）
var main_stages: Array[Stage] = []
## 临时阶段栈：栈底为最早被中断的阶段，栈顶为当前正在执行的临时阶段（若有），也可能包含未启动的请求阶段
var temp_stage_stack: Array[Stage] = []
var timer: GameTimer
var current_main_stage_index: int = -1

## 当前正在执行的阶段（主阶段或临时阶段）
var current_stage: Stage = null
var current_main_stage_name: StringName = &""
var current_player_id: int = 0

## 信号
signal stage_completed(stage: Stage)
signal stage_rolled_back(old_stage: Stage, new_stage: Stage)
signal temp_stages_cleared()
signal round_ended()
signal stage_changed(old_stage: Stage, new_stage: Stage)
signal temp_stage_started(temp_stage: Stage)
signal round_completed()
signal stage_entered(stage: Stage)
## 请求开始新一轮
signal request_new_round(player_id: int)

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

## 连接阶段信号
func connect_stage_to_manager(new_stage: Stage, game_state: GameState) -> void:
	if not new_stage.stage_ended.is_connected(_on_stage_ended):
		new_stage.stage_ended.connect(_on_stage_ended.bind(game_state))
	if not new_stage.request_reset_timer.is_connected(_on_stage_reset_timer_requested):
		new_stage.request_reset_timer.connect(_on_stage_reset_timer_requested.bind(game_state))

## 断开阶段信号
func _disconnect_stage_signals(stage: Stage, game_state: GameState) -> void:
	if stage.stage_ended.is_connected(_on_stage_ended):
		stage.stage_ended.disconnect(_on_stage_ended)
	if stage.request_reset_timer.is_connected(_on_stage_reset_timer_requested):
		stage.request_reset_timer.disconnect(_on_stage_reset_timer_requested)

func set_timer(_timer: GameTimer) -> void:
	timer = _timer

func handle_validated_request(request: OperationRequest, game_state: GameState) -> void:
	if not current_stage:
		push_error("StageManager: 当前阶段为空，无法处理操作请求")
		return
	current_stage.process_operation_request(request, game_state)

func complete_current_stage(game_state: GameState) -> void:
	if current_stage and not current_stage.is_ended:
		current_stage.end_stage(game_state)

## 清空所有临时阶段（结束并清空栈）
func complete_all_temp_stages(game_state: GameState) -> void:
	if temp_stage_stack.is_empty():
		return
	while not temp_stage_stack.is_empty():
		var stage = temp_stage_stack.pop_back()
		if not stage.is_ended:
			stage.end_stage(game_state)
	temp_stages_cleared.emit()

## 将临时阶段压入栈（不启动），若阶段已存在则忽略（由调用方保证）
func push_temp_stage(stage: Stage) -> void:
	if not stage.is_temporary():
		stage.temporary_stage_player_id = Stage.PUBLIC_PLAYER_ID
	temp_stage_stack.push_back(stage)

## 启动栈尾的临时阶段（若尚未启动）
func start_pending_temp_stage(game_state: GameState) -> void:
	if temp_stage_stack.is_empty():
		return
	var top_stage = temp_stage_stack[-1]
	if current_stage == top_stage:
		return
	_transition_to(top_stage, game_state)

## 结束当前回合
func end_round(game_state: GameState) -> void:
	if timer:
		timer.stop()
	if current_stage and not current_stage.is_ended:
		current_stage.end_stage(game_state)
	temp_stage_stack.clear()
	current_main_stage_name = &""
	current_player_id = 0
	current_stage = null
	current_main_stage_index = -1
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

## 切换到新阶段（断开旧阶段信号、连接新阶段、启动）
func _transition_to(new_stage: Stage, game_state: GameState) -> void:
	if not new_stage:
		return
	var old_stage = current_stage
	if old_stage:
		_disconnect_stage_signals(old_stage, game_state)
	current_stage = new_stage
	if not new_stage.is_temporary():
		current_main_stage_name = new_stage.stage_name
		complete_all_temp_stages(game_state)
	connect_stage_to_manager(new_stage, game_state)
	stage_changed.emit(old_stage, new_stage)
	_start_stage(new_stage, game_state)
## 回滚到上一个阶段（弹出栈顶临时阶段，恢复上一阶段）
func rollback_stage(game_state: GameState) -> void:
	if temp_stage_stack.is_empty():
		push_error("回滚失败：临时阶段栈为空")
		return
	var ended_stage = temp_stage_stack.pop_back()
	if not ended_stage:
		push_error("回滚的阶段无效")
		return
	if temp_stage_stack.is_empty():
		var main_stage = main_stages[current_main_stage_index]
		_transition_to(main_stage, game_state)
	else:
		var previous_stage = temp_stage_stack[-1]
		_transition_to(previous_stage, game_state)
	stage_rolled_back.emit(ended_stage, current_stage)
## 前进到下一个主阶段（内部使用，自动 +1）
func _advance_to_next_main_stage(game_state: GameState) -> void:
	current_main_stage_index += 1
	if current_main_stage_index >= main_stages.size():
		request_new_round.emit(current_player_id)
		return
	_transition_to(main_stages[current_main_stage_index], game_state)
## 切换到下一个主阶段，可额外跳过若干阶段
func switch_to_main_stage(game_state: GameState, skip_count: int = 0, disallowed_stages: Array[StringName] = []) -> void:
	var actual_skip = skip_count
	if not disallowed_stages.is_empty():
		var current_name = current_stage.stage_name if current_stage else MAIN_STAGE_NAMES[0]
		var idx = MAIN_STAGE_NAMES.find(current_name)
		if idx == -1:
			idx = current_main_stage_index
		var target_idx = (idx + 1) % MAIN_STAGE_NAMES.size()
		var steps = 0
		while disallowed_stages.has(MAIN_STAGE_NAMES[target_idx]) and steps < MAIN_STAGE_NAMES.size():
			target_idx = (target_idx + 1) % MAIN_STAGE_NAMES.size()
			steps += 1
		actual_skip = steps
	current_main_stage_index += actual_skip
	_advance_to_next_main_stage(game_state)
## 阶段结束回调
func _on_stage_ended(ended_stage: Stage, game_state: GameState) -> void:
	if ended_stage != current_stage:
		return
	if timer:
		timer.stop()
	stage_completed.emit(ended_stage)
## 计时器超时回调
func on_timer_timeout(game_state: GameState) -> void:
	if current_stage and not current_stage.is_ended:
		current_stage.timeout(game_state)
## 重置计时器请求
func _on_stage_reset_timer_requested(new_time_limit: float, game_state: GameState) -> void:
	if timer and current_stage and not current_stage.is_ended:
		timer.start(new_time_limit)
## 开始新回合
func start_round(player_id: int, game_state: GameState) -> void:
	end_round(game_state)
	current_main_stage_index = 0
	current_player_id = player_id
	temp_stage_stack.clear()
	_transition_to(main_stages[current_main_stage_index], game_state)
## 获取当前主阶段索引
func get_current_stage_enum() -> int:
	return current_main_stage_index
## 检查是否存在指定名称的阶段（包括当前阶段、临时阶段栈）
func has_stage_with_name(stage_name: StringName) -> bool:
	if current_stage and current_stage.stage_name == stage_name:
		return true
	for stage in temp_stage_stack:
		if stage.stage_name == stage_name:
			return true
	return false
