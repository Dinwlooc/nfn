extends Buff
class_name AttributeBuff

## 目标属性修饰器表
var attribute_modifiers: AttributeModifiers
## 受影响的属性名
var attribute: StringName
## 修饰类型（对应 AttributeModifiers 的 TYPE_* 常量）
var modifier_type: int
## 修饰器名称
var modifier_name: StringName
## 每层提供的数值
var value_per_stack: float

## 构造：绑定属性表与单层数值
func _init(p_buff_name: StringName, p_attribute_modifiers: AttributeModifiers, p_attribute: StringName, p_modifier_type: int, p_modifier_name: StringName, p_value_per_stack: float) -> void:
	super._init(p_buff_name)
	attribute_modifiers = p_attribute_modifiers
	attribute = p_attribute
	modifier_type = p_modifier_type
	modifier_name = p_modifier_name
	value_per_stack = p_value_per_stack

## 应用：把总加成写入属性表
## @hook @override
func on_apply() -> void:
	_apply_total_value()

## 移除：从属性表撤销本 Buff 的修饰
## @hook @override
func on_remove() -> void:
	attribute_modifiers.remove_modifier(attribute, modifier_type, modifier_name)

## 层数变化：非零则重算总加成，归零则移除
## @hook @override
func on_stack_changed(_old: int, new_stack: int) -> void:
	if new_stack > 0:
		_apply_total_value()
	else:
		attribute_modifiers.remove_modifier(attribute, modifier_type, modifier_name)

## 按 value_per_stack × 当前层数 写入一条属性修饰
## @side_effect
func _apply_total_value() -> void:
	var total: float = value_per_stack * stack_count
	attribute_modifiers.add_modifier(attribute, modifier_type, modifier_name, total)
