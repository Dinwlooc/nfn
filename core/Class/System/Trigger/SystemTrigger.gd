## 系统级触发器基类。子类构造函数必须接收 [System]。
@abstract
extends RefCounted
class_name SystemTrigger

var _system: System
## 断开所有信号连接。子类必须覆盖此方法。
@abstract func disconnect_all() -> void
## 构造函数，自动持有依赖。
func _init(system: System) -> void:
	_system = system
