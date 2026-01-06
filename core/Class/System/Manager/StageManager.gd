extends RefCounted
class_name StageManager

# 新增信号
signal stage_completed()  # 单个阶段完成（临时或主阶段）
signal stage_rolled_back(old_stage: Stage, new_stage: Stage)  # 阶段回退
signal temp_stages_cleared()  # 所有临时阶段被清除
signal round_ended()  # 回合结束信号
signal stage_changed(old_stage: Stage, new_stage: Stage)
signal temp_stage_started(temp_stage: Stage)
signal round_completed()

# 主阶段顺序数组（按游戏流程排列）
var main_stages: Array[Stage] = []
var current_stage: Stage = null
var temp_stage_stack: Array[Stage] = []
var timer: GameTimer
var game_state: GameState
var current_main_stage_index: int = -1  # 当前主阶段在顺序数组中的索引
var current_player_id:int = 0
var modifier_container:ModifierContainer
static var MAIN_STAGES:Array[Script] = [
		StageStart,
		StageDraw,
		StageMain,
		StageDiscard,
		StageEnd ]

func _init(p_game_state:GameState) -> void:
	game_state = p_game_state
	main_stages.resize(MAIN_STAGES.size())
	for i in MAIN_STAGES.size():
		main_stages[i] = MAIN_STAGES[i].new(game_state)
		connect_stage_to_manager(main_stages[i])

func connect_stage_to_manager(new_stage:Stage):
	new_stage.stage_ended.connect(_on_stage_ended)

func set_modifier_container(container: ModifierContainer) -> void:
	modifier_container = container

## 处理已验证的操作请求
func handle_validated_request(request: OperationRequest) -> void:
	current_stage.process_operation_request(request)

func set_timer(_timer: GameTimer):
	if timer:
		timer.timeout.disconnect(_on_timer_timeout)
	timer = _timer
	timer.timeout.connect(_on_timer_timeout)
# 新增方法：结束当前阶段（统一接口）
func complete_current_stage() -> void:
	if current_stage and not current_stage.is_ended:
		current_stage.end_stage()
# 新增方法：结束所有临时阶段
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

##插入临时阶段
func start_temp_stage(temp_stage: Stage) -> void:
	if current_stage:
		current_stage.pause()
	temp_stage.is_temporary = true
	connect_stage_to_manager(temp_stage)
	temp_stage_stack.append(current_stage)
	_transition_to(temp_stage)
	temp_stage_started.emit(temp_stage)
##结束当前回合
func end_round() -> void:
	if timer:
		timer.stop()
	if current_stage and not current_stage.is_ended:
		current_stage.end_stage_effect()
	temp_stage_stack.clear()
	current_main_stage_index = -1
	current_stage = null
	round_ended.emit()
	round_completed.emit()

# 修改后的阶段过渡核心方法
func _transition_to(new_stage: Stage) -> void:
	if not new_stage:
		return
	var old_stage:Stage = current_stage
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

##回退到上个阶段
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
##进入下一个主阶段
func _advance_to_next_main_stage() -> void:
	current_main_stage_index += 1
	if current_main_stage_index >= main_stages.size():
		# 所有主阶段完成，结束回合
		end_round()
		return
	_transition_to(main_stages[current_main_stage_index])

## 阶段结束处理器
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
## 计时器超时处理
func _on_timer_timeout() -> void:
	if current_stage and not current_stage.is_ended:
		complete_current_stage()  # 使用统一的结束接口

func start_round(player_id:int = 0) -> void:
	current_main_stage_index = 0
	current_player_id = player_id
	temp_stage_stack.clear()
	_transition_to(main_stages[current_main_stage_index])

func get_current_stage_enum()->int:
	return current_main_stage_index
