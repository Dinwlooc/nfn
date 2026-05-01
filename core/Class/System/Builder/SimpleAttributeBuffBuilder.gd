class_name SimpleAttributeBuffBuilder
extends RefCounted

## 创建简单属性Buff，根据属性名、类型与正负方向拼合修饰器名
static func create_attribute_buff(
	buff_name: StringName,
	attribute_modifiers: AttributeModifiers,
	attribute: StringName,
	modifier_type: int,
	is_positive: bool,
	value_per_stack: float,
	inborn_stack: int = 0
) -> AttributeBuff:
	var direction_str: StringName = &"positive" if is_positive else &"negative"
	var type_str: StringName = _get_type_string(modifier_type)
	var modifier_name: StringName = attribute + &"_" + type_str + &"_" + direction_str
	var buff: AttributeBuff = AttributeBuff.new(buff_name, attribute_modifiers, attribute, modifier_type, modifier_name, value_per_stack)
	buff.inborn_stack = inborn_stack
	return buff

static func _get_type_string(type: int) -> StringName:
	match type:
		AttributeModifiers.TYPE_BASE_ADD:
			return &"base_add"
		AttributeModifiers.TYPE_BASE_MULTIPLY:
			return &"base_multiply"
		AttributeModifiers.TYPE_FINAL_ADD:
			return &"final_add"
		AttributeModifiers.TYPE_FINAL_MULTIPLY:
			return &"final_multiply"
	return &"unknown"

## 快速配置组件层数属性。
## 将组件名作为属性名，在 attribute_modifiers 中设置其基础值。
## @param attribute_modifiers: 目标属性修饰器容器
## @param component_name: 组件名称（如 DestroyXModifier.get_component_name()）
## @param stack_value: 层数值（整数）
static func set_component_stack(attribute_modifiers: AttributeModifiers, component_name: StringName, stack_value: int) -> void:
	attribute_modifiers.add_modifier(component_name, AttributeModifiers.TYPE_BASE_ADD, component_name, float(stack_value))
