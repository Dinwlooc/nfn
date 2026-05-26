## 物品基类，所有可交互实体（卡牌、玩家等）的基础。
extends RefCounted
class_name Item

var _id: int = -1
var data: ItemData
var attributeModifiers: AttributeModifiers
var command_modifiers: CommandModifiers
var buff_modifiers: BuffModifiers
var rule_overrides: Dictionary
## 构造函数，接收一个 ItemData 蓝图
func _init(item_data: ItemData) -> void:
	data = item_data
	attributeModifiers = AttributeModifiers.new()
	command_modifiers = CommandModifiers.new()
	buff_modifiers = BuffModifiers.new(attributeModifiers, command_modifiers)
	_reset_to_data()
## 获取物品 ID
func get_id() -> int:
	return _id
## 设置物品 ID（由管理器调用），并根据虚方法 _get_owner_type 设置 BuffModifiers 所有者
func set_id(new_id: int) -> void:
	_id = new_id
	buff_modifiers.set_owner(_get_owner_type(), _id)
## 重置物品到蓝本状态（清除所有运行时修改）
func reset_item() -> void:
	_reset_to_data()
	buff_modifiers.reset_buffs()
## 内部方法：根据 data 重置属性基础值、修饰器和规则覆盖
func _reset_to_data() -> void:
	# 重置属性基础值
	for attr: StringName in data.attribute_defaults:
		attributeModifiers.set_base_value(attr, data.attribute_defaults[attr])
	# 重置命令修饰器
	command_modifiers.reset()
	for modifier_script: Script in data.modifiers:
		_add_modifier_internal(modifier_script)
	# 重置规则覆盖
	rule_overrides = data.rule_overrides.duplicate(true)
## 内部方法：添加修饰器脚本并调用其 init
func _add_modifier_internal(modifier_script: Script) -> void:
	command_modifiers.add_modifier(modifier_script)
	if modifier_script.has_method(&"init"):
		modifier_script.call(&"init", self)
## 添加运行时修饰器（不影响蓝本）
func add_modifier(modifier_script: Script) -> void:
	command_modifiers.add_modifier(modifier_script)
	if modifier_script.has_method(&"init"):
		modifier_script.call(&"init", self)
## 移除运行时修饰器
func remove_modifier(modifier_script: Script) -> void:
	command_modifiers.remove_modifier(modifier_script)
## 获取最终属性值（基础值 + 所有加成）
func get_attribute(attribute: StringName) -> int:
	return attributeModifiers.get_final_value(attribute)
## 获取规则覆盖字典
func get_rule_overrides() -> Dictionary:
	return rule_overrides
## 设置规则覆盖字典（运行时临时覆盖）
func set_rule_overrides(overrides: Dictionary) -> void:
	rule_overrides = overrides
## 虚方法：返回所有者类型字符串，用于 BuffModifiers 的 set_owner。
## 子类应重写此方法返回对应的类型，例如 &"card" 或 &"player"。
func _get_owner_type() -> StringName:
	return &"item"
