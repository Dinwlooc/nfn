extends RefCounted
class_name Stage

signal stage_ended(stage:Stage)
signal reset_response_locks()
signal whitelist_updated(permissions_map: Dictionary[int, Array], is_adapt_for_current_player: bool)
signal behavior_command_issued(command: BehaviorCommand)
var stage_name: StringName = &"Null"
var time_limit: float = 0.0  #0表示不需要计时
var is_temporary: bool = false
var game_state: GameState
var is_ended: bool = false  # 标记阶段是否已结束
var is_paused:bool = false

func _init(p_game_state: GameState) -> void:
	game_state = p_game_state
## 进入阶段
func enter() -> void:
	is_ended = false
	GlobalConsole._print(["Stage:进入",stage_name,"阶段"])
	enter_expand()
	run()

func run() -> void:
	pass

func enter_expand() -> void:
	pass
## 暂停阶段
func pause() -> void:
	is_paused = true
## 恢复阶段
func resume() -> void:
	pass
## 阶段结束效果
func end_stage_effect() -> void:
	pass
## 结束阶段
func end_stage() -> void:
	if is_ended:
		return
	is_ended = true
	is_paused = false
	end_stage_effect()
	stage_ended.emit(self)

func process_operation_request(request: OperationRequest) -> void:
	pass
