## 阶段基类，所有主阶段与临时阶段继承此类。
extends RefCounted
class_name Stage

#=== Properties ===
## 阶段名称，用于标识阶段类型
var stage_name: StringName = &"Null"
## 阶段时间限制（秒），0 表示无限制
var time_limit: float = 0.0
## 临时阶段归属玩家 ID（0 表示主阶段，非 0 表示临时阶段并属于该玩家）
var temporary_stage_player_id: int = 0
## 阶段是否已结束
var is_ended: bool = false
## 阶段是否暂停
var is_paused: bool = false

#=== Constants ===
## 公共玩家 ID，用于表示非专有阶段（如主阶段）或公开临时阶段
const PUBLIC_PLAYER_ID := 1

#=== Signals ===
## 请求重置计时器，新时限通过参数传递
## @requester
signal request_reset_timer(new_time_limit: float)

#=== Constructor ===
## 构造函数（无特殊初始化）
func _init() -> void:
	pass

#=== Public Methods ===
## 返回当前阶段是否为临时阶段
## @pure
func is_temporary() -> bool:
	return temporary_stage_player_id != 0
## 进入阶段（由管理器调用）
## @stack_local @side_effect
func enter(_game_state: GameState, _command_bus: CommandBus) -> void:
	is_ended = false
	GlobalConsole._print(["Stage:进入", stage_name, "阶段"])
## 暂停阶段
## @hook @stack_local @side_effect
func pause(_game_state: GameState, _command_bus: CommandBus) -> void:
	is_paused = true
## 恢复阶段
## @hook @stack_local @side_effect
func resume(_game_state: GameState, _command_bus: CommandBus) -> void:
	is_paused = false
## 阶段结束时的清理效果
## @hook @stack_local
func end_stage_effect(_game_state: GameState, _command_bus: CommandBus) -> void:
	pass
## 超时处理（默认发送结束命令）
## @hook @stack_local @side_effect
func timeout(_game_state: GameState, command_bus: CommandBus) -> void:
	var cmd := StageScheduleCommand.new(
		command_bus,
		StageScheduleCommand.Operation.END_CURRENT
	)
	command_bus.queue_behavior(cmd)
## 结束阶段（由管理器调用，仅变更内部状态，不触发信号）
## @side_effect @stack_local
func end_stage(game_state: GameState, command_bus: CommandBus) -> void:
	if is_ended:
		return
	is_ended = true
	is_paused = false
	end_stage_effect(game_state, command_bus)
## 请求结束当前阶段（发送命令）
## @stack_local
func request_end_stage(command_bus: CommandBus) -> void:
	var cmd := StageScheduleCommand.new(
		command_bus,
		StageScheduleCommand.Operation.END_CURRENT
	)
	command_bus.queue_behavior(cmd)
## 请求重置计时器（发射信号）
## @requester
func reset_timer(new_time_limit: float) -> void:
	request_reset_timer.emit(new_time_limit)
## 处理玩家操作请求（由管理器转发，子类按需重写）
## @hook @stack_local
func process_operation_request(_request: OperationRequest, _game_state: GameState, _command_bus: CommandBus) -> void:
	pass
## 刷新响应权：在命令全部完成后由触发器调用，
## @hook @stack_local
func refresh_response(_game_state: GameState, _command_bus: CommandBus) -> void:
	pass
