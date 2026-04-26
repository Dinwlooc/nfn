## 定时器超时转发至阶段管理器。
extends SystemTrigger
class_name TimerTimeoutTrigger

var _system: System

func _init(system: System) -> void:
	super(system)
	_system = system
	_system.timer.timeout.connect(_on_timeout)

func _on_timeout() -> void:
	_system.game_state.stage_manager.on_timer_timeout(_system.game_state)
