extends Buff
class_name AttributeBuff

## 要修改的属性名
var attribute: StringName
## 修饰器运算类型，使用AttributeModifiers的常量
var modifier_type: int
## 修饰器唯一名（用于AttributeModifiers内部索引）
var modifier_name: StringName
## 每层基础数值
var value_per_stack: float

func _init(p_buff_name: StringName, p_card: Card, p_attribute: StringName, p_modifier_type: int, p_modifier_name: StringName, p_value_per_stack: float) -> void:
	super._init(p_buff_name, p_card)
	attribute = p_attribute
	modifier_type = p_modifier_type
	modifier_name = p_modifier_name
	value_per_stack = p_value_per_stack

func on_apply() -> void:
	_apply_total_value()

func on_remove() -> void:
	card.attributeModifiers.remove_modifier(attribute, modifier_type, modifier_name)

func on_stack_changed(_old: int, new_stack: int) -> void:
	if new_stack > 0:
		_apply_total_value()
	else:
		card.attributeModifiers.remove_modifier(attribute, modifier_type, modifier_name)

func _apply_total_value() -> void:
	var total: float = value_per_stack * stack_count
	# 利用属性管理器的更新机制，若修饰器已存在则自动更新差值
	card.attributeModifiers.add_modifier(attribute, modifier_type, modifier_name, total)
