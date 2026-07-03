## 系统级触发器标记。子类构造函数必须接收 [System] 实例。
## 用于需要访问多个顶层模块的场景。
@abstract
extends RefCounted
class_name SystemTrigger

@abstract func _init(system: System) -> void
