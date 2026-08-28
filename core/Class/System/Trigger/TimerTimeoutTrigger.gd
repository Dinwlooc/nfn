extends SystemTrigger
class_name TimerTimeoutTrigger

func _init(system: System) -> void:
	super._init(system)
	_system.timer.timeout.connect(_on_timeout)
## 定时器超时转发给阶段管理器
## @signal-listener
func _on_timeout() -> void:
	_system.game_state.stage_manager.on_timer_timeout(_system.game_state, _system.command_bus)
##
func disconnect_all() -> void:
	_system.timer.timeout.disconnect(_on_timeout)
