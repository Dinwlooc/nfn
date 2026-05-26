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
	# 连接命令完成信号（子类在调用 super 前必须完成自己的初始化）
	_connect_all_commands_completed_signal(game_state)

## 暂停阶段
func pause(game_state: GameState) -> void:
	is_paused = true
	# 断开信号，避免暂停期间响应
	_disconnect_all_commands_completed_signal(game_state)

## 恢复阶段
func resume(game_state: GameState) -> void:
	is_paused = false
	# 重新连接信号
	_connect_all_commands_completed_signal(game_state)

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
	# 先断开信号，避免清理过程中触发回调
	_disconnect_all_commands_completed_signal(game_state)
	end_stage_effect(game_state)
	stage_ended.emit(self)

## 处理玩家操作请求（由管理器转发）
func process_operation_request(_request: OperationRequest, _game_state: GameState) -> void:
	pass

# ------------------ 命令空闲期恢复响应权的规范实现 ------------------
## 连接命令完成信号，并将回调绑定到子类实现的抽象方法
func _connect_all_commands_completed_signal(game_state: GameState) -> void:
	# 先断开已有连接，避免重复
	_disconnect_all_commands_completed_signal(game_state)
	if not game_state:
		return
	game_state.all_commands_completed.connect(_on_all_commands_completed_impl)

## 断开命令完成信号连接
func _disconnect_all_commands_completed_signal(game_state: GameState) -> void:
	if game_state and game_state.all_commands_completed.is_connected(_on_all_commands_completed_impl):
		game_state.all_commands_completed.disconnect(_on_all_commands_completed_impl)

## 抽象方法：子类必须实现，定义命令全部完成后的恢复响应权行为
func _on_all_commands_completed_impl(_game_state: GameState) -> void:
	pass
