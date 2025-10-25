extends Label
# 使用StringName优化性能
const TIMER_TYPE: StringName = &"timer"
# 缓存计时器实例
var _timer: GameTimer = null
# 上次显示的整数值（用于避免不必要的更新）
var _last_displayed_value: int = -1

func _ready() -> void:
	GlobalRegistry.connect_singleton(TIMER_TYPE, _on_timer_registered)

func _on_timer_registered(instance: Node) -> void:
	if instance is GameTimer:
		_timer = instance

func _physics_process(_delta: float) -> void:
	if not _timer:
		return
	var time_left: float = _timer.time_left
	var current_value: int = ceili(time_left)
	if current_value != _last_displayed_value:
		_last_displayed_value = current_value
		text = str(current_value)
