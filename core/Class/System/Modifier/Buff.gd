extends RefCounted
class_name Buff

## Buff 唯一名（同名 Buff 视为同一种）
var buff_name: StringName
## 当前层数
var stack_count: int = 1
## 锁定外部修改，但层数归零时无论如何都会被移除
var locked: bool = false
## 固有层数，重置时若>0则恢复至此层数，否则被移除
var inborn_stack: int = 0

## 构造：设定 Buff 名
func _init(p_buff_name: StringName) -> void:
	buff_name = p_buff_name

## 应用时的效果，子类重写
## @hook
func on_apply() -> void:
	pass

## 移除时的效果，子类重写
## @hook
func on_remove() -> void:
	pass

## 层数变化时的效果，子类重写
## @hook
func on_stack_changed(_old_stack: int, _new_stack: int) -> void:
	pass

## 是否允许被外部移除（受 locked 约束）
func can_remove() -> bool:
	return not locked

## 设置锁定状态
func set_locked(value: bool) -> void:
	locked = value
