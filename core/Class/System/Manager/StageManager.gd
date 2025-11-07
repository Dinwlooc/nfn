extends RefCounted
class_name StageManager

signal stage_changed(old_stage: Stage, new_stage: Stage)
signal temp_stage_started(temp_stage: Stage)
signal round_completed()
signal reset_response_locks_forwarded()
signal whitelist_updated_forwarded(permissions_map: Dictionary[int,Array])
signal behavior_command_forwarded(command: BehaviorCommand)
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
var current_player_id:int = 0

func _init(p_system:System) -> void:
	system = p_system
	main_stages = {
		GlobalConstants.GameStage.START: StageStart.new(system),
		GlobalConstants.GameStage.DRAW: StageDraw.new(system),
		GlobalConstants.GameStage.MAIN: StageMain.new(system),
		GlobalConstants.GameStage.DISCARD: StageDiscard.new(system),
		GlobalConstants.GameStage.END: StageEnd.new(system)
	}

##处理已验证的操作请求
func handle_validated_request(request: OperationRequest) -> void:
	current_stage.process_operation_request(request)

func set_timer(_timer: GameTimer):
	if timer:
		timer.timeout.disconnect(_on_timer_timeout)
	timer = _timer
	timer.timeout.connect(_on_timer_timeout)

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
		old_stage.stage_ended.disconnect(_on_stage_ended)
		old_stage.reset_response_locks.disconnect(_on_reset_locks)
		old_stage.whitelist_updated.disconnect(_on_whitelist_updated)
		old_stage.behavior_command_issued.disconnect(_on_behavior_command)
	current_stage = new_stage
	if new_stage:
		new_stage.stage_ended.connect(_on_stage_ended.bind(new_stage))
		new_stage.reset_response_locks.connect(_on_reset_locks)
		new_stage.whitelist_updated.connect(_on_whitelist_updated)
		new_stage.behavior_command_issued.connect(_on_behavior_command)
		if new_stage.time_limit > 0.0:
			timer.start(new_stage.time_limit)
		else:
			timer.stop()
		new_stage.call_deferred(&"enter")
	stage_changed.emit(old_stage, new_stage)
func _on_reset_locks():
	reset_response_locks_forwarded.emit()
func _on_whitelist_updated(permissions_map: Dictionary, is_adapt_for_current_player: bool = false):
	if is_adapt_for_current_player and permissions_map.has(-1):
		var modified_map = permissions_map.duplicate() 
		modified_map[current_player_id] = modified_map[-1]
		modified_map.erase(-1)
		whitelist_updated_forwarded.emit(modified_map)
	else:
		whitelist_updated_forwarded.emit(permissions_map)
func _on_behavior_command(command: BehaviorCommand):
	behavior_command_forwarded.emit(command)
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
func start_round(player_id:int = 0) -> void:
	current_main_stage_index = 0
	current_player_id = player_id
	_transition_to(main_stages[MAIN_STAGE_ORDER[current_main_stage_index]])
func change_stage(new_stage: GlobalConstants.GameStage) -> void:
	if new_stage not in main_stages:
		push_error("尝试切换到无效阶段: " + str(new_stage))
		return
	current_main_stage_index = MAIN_STAGE_ORDER.find(new_stage)
	if current_main_stage_index == -1:
		push_error("尝试切换到未注册的主阶段: " + str(new_stage))
		return
	_transition_to(main_stages[new_stage])

func get_current_stage_enum()->int:
	return current_main_stage_index
