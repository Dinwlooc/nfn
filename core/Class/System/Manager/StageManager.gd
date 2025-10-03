extends RefCounted
class_name StageManager

signal stage_changed(old_stage: Stage, new_stage: Stage)
signal temp_stage_started(temp_stage: Stage)
signal round_completed()  # 新增信号：当整个回合循环结束时发出

# 主阶段顺序数组（按游戏流程排列）
var MAIN_STAGE_ORDER: Array[GlobalConstants.GameStage] = [
	GlobalConstants.GameStage.START,
	GlobalConstants.GameStage.DRAW,
	GlobalConstants.GameStage.MAIN,
	GlobalConstants.GameStage.DISCARD,
	GlobalConstants.GameStage.END
]
var main_stages: Dictionary = {}
var current_stage: Stage = null
var temp_stage_stack: Array[Stage] = []
var timer: GameTimer
var system: System
var current_main_stage_index: int = -1  # 当前主阶段在顺序数组中的索引

func _init(p_system:System, p_timer: GameTimer) -> void:
	system = p_system
	timer = p_timer
	timer.timeout.connect(_on_timer_timeout)
	main_stages = {
		GlobalConstants.GameStage.START: StageStart.new(system),
		GlobalConstants.GameStage.DRAW: StageDraw.new(system),
		GlobalConstants.GameStage.MAIN: StageMain.new(system),
		GlobalConstants.GameStage.DISCARD: StageDiscard.new(system),
		GlobalConstants.GameStage.END: StageEnd.new(system)
	}
# 开始回合（从第一个主阶段开始）
func start_round() -> void:
	current_main_stage_index = 0
	_transition_to(main_stages[MAIN_STAGE_ORDER[current_main_stage_index]])

# 切换到指定主阶段
func change_stage(new_stage: GlobalConstants.GameStage) -> void:
	if new_stage not in main_stages:
		push_error("尝试切换到无效阶段: " + str(new_stage))
		return
	current_main_stage_index = MAIN_STAGE_ORDER.find(new_stage)
	if current_main_stage_index == -1:
		push_error("尝试切换到未注册的主阶段: " + str(new_stage))
		return
	_transition_to(main_stages[new_stage])

# 进入下一个主阶段（核心新增逻辑）
func _advance_to_next_main_stage() -> void:
	current_main_stage_index += 1
	if current_main_stage_index >= MAIN_STAGE_ORDER.size():
		round_completed.emit()  # 通知系统回合结束
		return
	var next_stage = MAIN_STAGE_ORDER[current_main_stage_index]
	_transition_to(main_stages[next_stage])
# 临时阶段相关方法保持不变...
func start_temp_stage(temp_stage: Stage) -> void:
	if current_stage:
		current_stage.pause()
	temp_stage.is_temporary = true
	temp_stage_stack.append(current_stage)
	_transition_to(temp_stage)
	temp_stage_started.emit(temp_stage)

func end_temp_stage() -> void:
	if temp_stage_stack.is_empty():
		push_error("没有活动的临时阶段")
		return
	var previous_stage = temp_stage_stack.pop_back()
	if current_stage:
		current_stage.end_stage_effect()
	if previous_stage:
		previous_stage.resume()
		_transition_to(previous_stage)
# 阶段过渡核心方法
func _transition_to(new_stage: Stage) -> void:
	var old_stage = current_stage
	if old_stage:
		if old_stage.stage_ended.is_connected(_on_stage_ended):
			old_stage.stage_ended.disconnect(_on_stage_ended)
	current_stage = new_stage
	if new_stage:
		if not new_stage.stage_ended.is_connected(_on_stage_ended):
			new_stage.stage_ended.connect(_on_stage_ended.bind(new_stage))
		if new_stage.time_limit > 0.0:
			timer.start(new_stage.time_limit)
		else:
			timer.stop()
		new_stage.enter()
	stage_changed.emit(old_stage, new_stage)
func _on_stage_ended(ended_stage: Stage) -> void:
	if ended_stage != current_stage:
		return
	if ended_stage.is_temporary:
		end_temp_stage()
	else:
		timer.stop()
		_advance_to_next_main_stage()
func _on_timer_timeout() -> void:
	if current_stage and not current_stage.is_ended:
		current_stage.execute_default_action()
		current_stage.end_stage()
