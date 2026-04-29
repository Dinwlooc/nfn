## 简单属性Buff构建器，根据属性名、数值类型与正负方向拼合修饰器名并创建AttributeBuff
extends RefCounted
class_name SimpleAttributeBuffBuilder
## 创建属性Buff
## @param buff_name: Buff唯一标识名（命名空间）
## @param card: 目标卡牌
## @param attribute: 属性名
## @param modifier_type: 修饰器运算类型（使用AttributeModifiers的TYPE_*常量）
## @param is_positive: 是否为正向（true为正向增加，false为负向减少）
## @param value_per_stack: 每层基础数值
## @param inborn_stack: 固有层数，默认0
## @return AttributeBuff实例
static func create_attribute_buff(buff_name: StringName, card: Card, attribute: StringName, modifier_type: int, is_positive: bool, value_per_stack: float, inborn_stack: int = 0) -> AttributeBuff:
	var direction_str: StringName = &"positive" if is_positive else &"negative"
	var type_str: StringName = _get_type_string(modifier_type)
	var modifier_name: StringName = attribute + &"_" + type_str + &"_" + direction_str
	var buff: AttributeBuff = AttributeBuff.new(buff_name, card, attribute, modifier_type, modifier_name, value_per_stack)
	buff.inborn_stack = inborn_stack
	return buff
## 将修饰器类型常量转换为字符串标识
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
