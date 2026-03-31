extends RefCounted
class_name Stage

var stage_name: StringName = &"Null"
var time_limit: float = 0.0
var is_temporary: bool = false
var is_ended: bool = false
var is_paused: bool = false

signal stage_ended(stage: Stage)
signal request_reset_timer(new_time_limit: float)

# 存储命令完成信号的绑定回调，用于安全断开
var _all_commands_completed_binding: Callable = Callable()

func _init() -> void:
	pass

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
	_all_commands_completed_binding = _on_all_commands_completed_impl.bind(game_state)
	game_state.all_commands_completed.connect(_all_commands_completed_binding)

## 断开命令完成信号连接
func _disconnect_all_commands_completed_signal(game_state: GameState) -> void:
	if _all_commands_completed_binding == Callable():
		return
	if game_state and game_state.all_commands_completed.is_connected(_all_commands_completed_binding):
		game_state.all_commands_completed.disconnect(_all_commands_completed_binding)
	_all_commands_completed_binding = Callable()

## 抽象方法：子类必须实现，定义命令全部完成后的恢复响应权行为
func _on_all_commands_completed_impl(_game_state: GameState) -> void:
	pass
