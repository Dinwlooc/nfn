extends RefCounted
class_name StageManager

signal stage_changed(old_stage: Stage, new_stage: Stage)
signal temp_stage_started(temp_stage: Stage)
signal round_completed()
signal reset_response_locks_forwarded()
signal whitelist_updated_forwarded(permissions_map: Dictionary[int,Array])
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
		new_stage.reset_response_locks.connect(_on_reset_locks)
		new_stage.whitelist_updated.connect(_on_whitelist_updated)

func set_modifier_container(container: ModifierContainer) -> void:
	modifier_container = container
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
	if current_main_stage_index >= main_stages.size():
		round_completed.emit()  # 通知系统回合结束
		return
	_transition_to(main_stages[current_main_stage_index])
# 临时阶段相关方法保持不变...
func start_temp_stage(temp_stage: Stage) -> void:
	if current_stage:
		current_stage.pause()
	temp_stage.is_temporary = true
	connect_stage_to_manager(temp_stage)
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
	current_stage = new_stage
	if new_stage:
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
	_transition_to(main_stages[current_main_stage_index])

func get_current_stage_enum()->int:
	return current_main_stage_index
