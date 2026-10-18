extends SystemTrigger
class_name TimerTimeoutTrigger

## 构造：接管系统并连接计时器超时信号
func _init(system: System) -> void:
	super._init(system)
	_system.timer.timeout.connect(_on_timeout)
## 定时器超时转发给阶段管理器
## @signal_listener
func _on_timeout() -> void:
	_system.game_state.stage_manager.on_timer_timeout(_system.game_state, _system.command_bus)
##
func disconnect_all() -> void:
	_system.timer.timeout.disconnect(_on_timeout)
