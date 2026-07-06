extends RefCounted
class_name Stage

var stage_name: StringName = &"Null"
var time_limit: float = 0.0
## 临时阶段归属玩家 ID（0 表示主阶段，非 0 表示临时阶段并属于该玩家）
var temporary_stage_player_id: int = 0
var is_ended: bool = false
var is_paused: bool = false
const PUBLIC_PLAYER_ID := 1
signal stage_ended(stage: Stage)
signal request_reset_timer(new_time_limit: float)

func _init() -> void:
	pass
## 返回当前阶段是否为临时阶段
func is_temporary() -> bool:
	return temporary_stage_player_id != 0
## 进入阶段（由管理器调用）
func enter(game_state: GameState) -> void:
	is_ended = false
	GlobalConsole._print(["Stage:进入", stage_name, "阶段"])
## 暂停阶段
func pause(game_state: GameState) -> void:
	is_paused = true
## 恢复阶段
func resume(game_state: GameState) -> void:
	is_paused = false
## 阶段结束时的清理效果（供子类重写）
func end_stage_effect(_game_state: GameState) -> void:
	pass
## 超时处理（默认结束阶段，子类可重写以实现自定义超时行为）
func timeout(game_state: GameState) -> void:
	end_stage(game_state)
## 结束阶段
func end_stage(game_state: GameState) -> void:
	if is_ended:
		return
	is_ended = true
	is_paused = false
	end_stage_effect(game_state)
	stage_ended.emit(self)
## 处理玩家操作请求（由管理器转发）
func process_operation_request(_request: OperationRequest, _game_state: GameState) -> void:
	pass
## 刷新响应权：在命令全部完成后由触发器调用，子类重写以实现阶段特有的响应刷新逻辑
func refresh_response(_game_state: GameState) -> void:
	pass
