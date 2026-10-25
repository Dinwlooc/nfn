extends SystemTrigger
class_name TimerTimeoutTrigger

## 计时器引用（由全局注册表取得）
var _timer: GameTimer

## 构造：订阅注册表，GameTimer 就绪后注入系统并连接超时信号
func _init(system: System) -> void:
	super._init(system)
	GlobalRegistry.connect_singleton(GlobalRegistry.TIMER_TYPE, _on_timer_registered)
## 注册回调：注入 game_state 与阶段管理器，并连接超时信号
func _on_timer_registered(instance: Node) -> void:
	if not (instance is GameTimer) or instance == _timer:
		return
	_timer = instance
	if not _timer.timeout.is_connected(_on_timeout):
		_timer.timeout.connect(_on_timeout)
	_system.game_state.timer = _timer
	_system.game_state.stage_manager.set_timer(_timer)
## 定时器超时转发给阶段管理器
## @signal_listener
func _on_timeout() -> void:
	_system.game_state.stage_manager.on_timer_timeout(_system.game_state, _system.command_bus)
##
func disconnect_all() -> void:
	if _timer == null or not is_instance_valid(_timer):
		return
	if _timer.timeout.is_connected(_on_timeout):
		_timer.timeout.disconnect(_on_timeout)
	_timer = null
