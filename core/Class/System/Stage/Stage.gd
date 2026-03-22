extends RefCounted
class_name Stage

signal stage_ended(stage: Stage)
var stage_name: StringName = &"Null"
var time_limit: float = 0.0         # 0 表示不需要计时
var is_temporary: bool = false
var is_ended: bool = false
var is_paused: bool = false

func _init() -> void:
	pass

## 进入阶段（由管理器调用）
func enter(game_state: GameState) -> void:
	is_ended = false
	GlobalConsole._print(["Stage:进入", stage_name, "阶段"])

## 阶段主逻辑（供子类重写）
func run(game_state: GameState) -> void:
	pass

## 暂停阶段
func pause(game_state: GameState) -> void:
	is_paused = true

## 恢复阶段
func resume(game_state: GameState) -> void:
	is_paused = false

## 阶段结束时的清理效果（供子类重写）
func end_stage_effect(game_state: GameState) -> void:
	pass

## 结束阶段（由管理器调用）
func end_stage(game_state: GameState) -> void:
	if is_ended:
		return
	is_ended = true
	is_paused = false
	end_stage_effect(game_state)
	stage_ended.emit(self)

## 处理玩家操作请求（由管理器转发）
func process_operation_request(request: OperationRequest, game_state: GameState) -> void:
	pass
