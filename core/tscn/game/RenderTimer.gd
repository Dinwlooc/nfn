extends Label
# 使用StringName优化性能
## 全局注册表中的计时器类型键
const TIMER_TYPE: StringName = &"timer"
## 缓存计时器实例
var _timer: GameTimer = null
## 上次显示的整数值（用于避免不必要的更新）
var _last_displayed_value: int = -1

## 订阅计时器注册，拿到实例后开始显示倒计时
func _ready() -> void:
	GlobalRegistry.connect_singleton(TIMER_TYPE, _on_timer_registered)

## 计时器注册回调：只接受 GameTimer 实例
func _on_timer_registered(instance: Node) -> void:
	if instance is GameTimer:
		_timer = instance

## 每物理帧把剩余秒数取整显示，值未变则不刷新
func _physics_process(_delta: float) -> void:
	if not _timer:
		return
	var time_left: float = _timer.time_left
	var current_value: int = ceili(time_left)
	if current_value != _last_displayed_value:
		_last_displayed_value = current_value
		text = str(current_value)
