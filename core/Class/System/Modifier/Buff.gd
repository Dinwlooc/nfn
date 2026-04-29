extends RefCounted
class_name Buff

## Buff唯一标识名，通常采用命名空间形式，如 "fire/ignite"
var buff_name: StringName
## 当前层数
var stack_count: int = 1
## 是否锁定，锁定后外部无法移除层数，仅Buff自身可以修改
var locked: bool = false
## 固有层数，buff重置时若该值大于0，层数将恢复至此值而非被清除
var inborn_stack: int = 0
## 所属卡牌引用
var card: Card
## 可选的状态机引用，留待后续扩展
var state_machine = null

func _init(p_buff_name: StringName, p_card: Card) -> void:
	buff_name = p_buff_name
	card = p_card

## Buff被施加时调用（首次添加或从零到一层）
func on_apply() -> void:
	pass

## Buff被完全移除时调用（层数归零）
func on_remove() -> void:
	pass

## 层数发生变化时调用（不包括归零情况，归零调用on_remove）
func on_stack_changed(old_stack: int, new_stack: int) -> void:
	pass

## 检查是否可被外部移除（默认仅非锁定时可移除）
func can_remove() -> bool:
	return not locked

## 设置锁定状态
func set_locked(value: bool) -> void:
	locked = value
