extends RefCounted
class_name Buff

var buff_name: StringName
var stack_count: int = 1
## 锁定外部修改，但层数归零时无论如何都会被移除
var locked: bool = false
## 固有层数，重置时若>0则恢复至此层数，否则被移除
var inborn_stack: int = 0

func _init(p_buff_name: StringName) -> void:
	buff_name = p_buff_name

func on_apply() -> void:
	pass

func on_remove() -> void:
	pass

func on_stack_changed(_old_stack: int, _new_stack: int) -> void:
	pass

func can_remove() -> bool:
	return not locked

func set_locked(value: bool) -> void:
	locked = value
