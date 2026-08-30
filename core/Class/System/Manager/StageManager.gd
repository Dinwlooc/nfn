## 阶段管理器：管理主阶段与临时阶段的生命周期
extends RefCounted
class_name StageManager

#=== Signals ===
## 阶段完成信号
## @emitter
signal stage_completed(stage: Stage)
## 阶段回滚信号
## @emitter
signal stage_rolled_back(old_stage: Stage, new_stage: Stage)
## 临时阶段清空信号
## @emitter
signal temp_stages_cleared()
## 回合结束信号
## @emitter
signal round_ended()
## 阶段变更信号
## @emitter
signal stage_changed(old_stage: Stage, new_stage: Stage)
## 临时阶段启动信号
## @emitter
signal temp_stage_started(temp_stage: Stage)
## 回合完成信号
## @emitter
signal round_completed()
## 阶段进入信号
## @emitter
signal stage_entered(stage: Stage)
## 请求开始新一轮信号
## @requester
signal request_new_round(player_id: int)

#=== Constants & Static ===
## 主阶段名称列表（顺序循环）
static var MAIN_STAGE_NAMES: PackedStringArray = [
	&"Start",
	&"Draw",
	&"Main",
	&"Discard",
	&"End"
]
## 主阶段脚本类列表（与名称一一对应）
static var MAIN_STAGES_SCRIPTS: Array[Script] = [
	StageStart,
	StageDraw,
	StageMain,
	StageDiscard,
	StageEnd
]

#=== Variables ===
## 主阶段列表（按顺序循环）
var main_stages: Array[Stage] = []
## 临时阶段栈：栈底为最早被中断的阶段，栈顶为当前正在执行的临时阶段（若有），也可能包含未启动的请求阶段
var temp_stage_stack: Array[Stage] = []
## 游戏计时器引用
var timer: GameTimer
## 当前主阶段索引
var current_main_stage_index: int = -1
## 当前正在执行的阶段（主阶段或临时阶段）
var current_stage: Stage = null
## 当前主阶段名称
var current_main_stage_name: StringName = &""
## 当前玩家 ID
var current_player_id: int = 0

#=== Constructor ===
## 构造方法：初始化主阶段列表，并永久连接主阶段的 reset_timer 信号
## @side_effect
func _init() -> void:
	main_stages.resize(MAIN_STAGES_SCRIPTS.size())
	for i in MAIN_STAGES_SCRIPTS.size():
		main_stages[i] = MAIN_STAGES_SCRIPTS[i].new()
		_connect_request_reset_timer(main_stages[i])

#=== Public Methods ===
## 设置游戏计时器
## @internal
func set_timer(_timer: GameTimer) -> void:
	timer = _timer
## 处理已验证的操作请求
## @stack_local @internal
func handle_validated_request(request: OperationRequest, game_state: GameState, command_bus: CommandBus) -> void:
	if not current_stage:
		push_error("StageManager: 当前阶段为空，无法处理操作请求")
		return
	current_stage.process_operation_request(request, game_state, command_bus)
## 结束当前阶段（发送命令方式）
## @stack_local @internal
func complete_current_stage(game_state: GameState, command_bus: CommandBus) -> void:
	end_current_stage(game_state, command_bus)
## 清空所有临时阶段（结束并清空栈）
## @stack_local @internal @emitter
func complete_all_temp_stages(game_state: GameState, command_bus: CommandBus) -> void:
	if temp_stage_stack.is_empty():
		return
	while not temp_stage_stack.is_empty():
		var stage: Stage = temp_stage_stack.pop_back()
		_disconnect_request_reset_timer(stage)
		if not stage.is_ended:
			stage.end_stage(game_state, command_bus)
	temp_stages_cleared.emit()
## 将临时阶段压入栈（不启动），若阶段已存在则忽略（由调用方保证）
## @internal
func push_temp_stage(stage: Stage) -> void:
	if not stage.is_temporary():
		stage.temporary_stage_player_id = Stage.PUBLIC_PLAYER_ID
	temp_stage_stack.push_back(stage)
	_connect_request_reset_timer(stage)
## 启动栈尾的临时阶段（若尚未启动）
## @internal
func start_pending_temp_stage(game_state: GameState, command_bus: CommandBus) -> void:
	if temp_stage_stack.is_empty():
		return
	var top_stage: Stage = temp_stage_stack[-1]
	if current_stage == top_stage:
		return
	_transition_to(top_stage, game_state, command_bus)
## 结束当前回合
## @stack_local @internal @emitter
func end_round(game_state: GameState, command_bus: CommandBus) -> void:
	end_current_stage(game_state, command_bus)
	for stage in temp_stage_stack:
		_disconnect_request_reset_timer(stage)
	temp_stage_stack.clear()
	current_main_stage_name = &""
	current_player_id = 0
	current_stage = null
	current_main_stage_index = -1
	round_ended.emit()
	round_completed.emit()
## 回滚到上一个阶段（弹出栈顶临时阶段，恢复上一阶段）
## @stack_local @internal @emitter
func rollback_stage(game_state: GameState, command_bus: CommandBus) -> void:
	end_current_stage(game_state, command_bus)
	if temp_stage_stack.is_empty():
		push_error("回滚失败：临时阶段栈为空")
		return
	var ended_stage: Stage = temp_stage_stack.pop_back()
	_disconnect_request_reset_timer(ended_stage)
	if not ended_stage:
		push_error("回滚的阶段无效")
		return
	var roll_stage: Stage = main_stages[current_main_stage_index] if temp_stage_stack.is_empty() else temp_stage_stack[-1]
	_transition_to(roll_stage, game_state, command_bus)
	stage_rolled_back.emit(ended_stage, current_stage)
## 切换到下一个主阶段，可额外跳过若干阶段
## @internal
func switch_to_main_stage(game_state: GameState, skip_count: int = 0, disallowed_stages: Array[StringName] = [], command_bus: CommandBus = null) -> void:
	end_current_stage(game_state, command_bus)
	var actual_skip: int = skip_count
	if not disallowed_stages.is_empty():
		var current_name: StringName = current_stage.stage_name if current_stage else MAIN_STAGE_NAMES[0]
		var idx: int = MAIN_STAGE_NAMES.find(current_name)
		if idx == -1:
			idx = current_main_stage_index
		var target_idx: int = (idx + 1) % MAIN_STAGE_NAMES.size()
		var steps: int = 0
		while disallowed_stages.has(MAIN_STAGE_NAMES[target_idx]) and steps < MAIN_STAGE_NAMES.size():
			target_idx = (target_idx + 1) % MAIN_STAGE_NAMES.size()
			steps += 1
		actual_skip = steps
	current_main_stage_index += actual_skip
	_advance_to_next_main_stage(game_state, command_bus)
## 开始新回合
## @internal @emitter
func start_round(player_id: int, game_state: GameState, command_bus: CommandBus) -> void:
	if current_stage:
		end_round(game_state, command_bus)
	current_main_stage_index = 0
	current_player_id = player_id
	temp_stage_stack.clear()
	_transition_to(main_stages[current_main_stage_index], game_state, command_bus)
## 获取当前主阶段索引（枚举值）
## @pure
func get_current_stage_enum() -> int:
	return current_main_stage_index
## 检查是否存在指定名称的阶段（包括当前阶段、临时阶段栈）
## @pure
func has_stage_with_name(stage_name: StringName) -> bool:
	if current_stage and current_stage.stage_name == stage_name:
		return true
	for stage in temp_stage_stack:
		if stage.stage_name == stage_name:
			return true
	return false
## 结束当前阶段（执行清理，发射 stage_completed）
## @stack_local @internal @emitter
func end_current_stage(game_state: GameState, command_bus: CommandBus) -> void:
	if not current_stage or current_stage.is_ended:
		return
	if timer:
		timer.stop()
	current_stage.end_stage(game_state, command_bus)
	stage_completed.emit(current_stage)
## 计时器超时回调（由外部定时器信号触发）
## @stack_local @signal_listener @internal
func on_timer_timeout(game_state: GameState, command_bus: CommandBus) -> void:
	if current_stage and not current_stage.is_ended:
		current_stage.timeout(game_state, command_bus)

#=== Private Methods ===
## 连接 request_reset_timer 信号
## @signal_listener
func _connect_request_reset_timer(stage: Stage) -> void:
	stage.request_reset_timer.connect(_on_stage_reset_timer_requested)
## 断开 request_reset_timer 信号
## @signal_listener
func _disconnect_request_reset_timer(stage: Stage) -> void:
	stage.request_reset_timer.disconnect(_on_stage_reset_timer_requested)
## 启动阶段：启动计时器，调用 enter/resume，发出 stage_entered 信号
## @stack_local @side_effect @emitter
func _start_stage(stage: Stage, game_state: GameState, command_bus: CommandBus) -> void:
	timer.stop()
	if stage.time_limit > 0.0:
		timer.start(stage.time_limit)
	if stage.is_paused:
		stage.resume(game_state, command_bus)
		return
	stage.enter(game_state, command_bus)
	stage_entered.emit(stage)
## 切换到新阶段（不负责信号连接/断开，由外部栈操作管理）
## @side_effect @emitter
func _transition_to(new_stage: Stage, game_state: GameState, command_bus: CommandBus) -> void:
	if not new_stage:
		return
	var old_stage: Stage = current_stage
	current_stage = new_stage
	if not new_stage.is_temporary():
		current_main_stage_name = new_stage.stage_name
		complete_all_temp_stages(game_state, command_bus)
	stage_changed.emit(old_stage, new_stage)
	_start_stage(new_stage, game_state, command_bus)
## 前进到下一个主阶段（内部使用，自动 +1）
## @internal @emitter
func _advance_to_next_main_stage(game_state: GameState, command_bus: CommandBus) -> void:
	current_main_stage_index += 1
	if current_main_stage_index >= main_stages.size():
		request_new_round.emit(current_player_id)
		return
	_transition_to(main_stages[current_main_stage_index], game_state, command_bus)
## 重置计时器请求信号处理
## @signal_listener @internal @stack_local
func _on_stage_reset_timer_requested(new_time_limit: float) -> void:
	if timer and current_stage and not current_stage.is_ended:
		timer.start(new_time_limit)
