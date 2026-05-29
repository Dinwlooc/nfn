## 物品数据蓝图，作为共享只读资源，定义物品的静态属性和默认行为。
extends Resource
class_name ItemData

## 属性修饰器列表（内嵌子资源，不建议跨物品共享）
@export var attribute_defaults: Array[AttributeData] = []
## 预置修饰器脚本列表
@export var modifiers: Array[Script] = []
## 规则覆盖字典
@export var rule_overrides: Dictionary = {}
## 指定对应的 ItemPack 子类
@export var pack_class: Script
## 编辑器重置按钮：勾选后立即重置 attribute_defaults 为默认配置
@export var _reset_to_defaults: bool = false:
	set(value):
		if value:
			reset_attribute_defaults()
			_reset_to_defaults = false
			notify_property_list_changed()

func _init() -> void:
	if attribute_defaults.is_empty():
		reset_attribute_defaults()

## 重置属性默认值数组为子类提供的默认配置
func reset_attribute_defaults() -> void:
	attribute_defaults.clear()
	var defaults: Array[AttributeData] = _get_default_attribute_modifiers()
	for attr_data: AttributeData in defaults:
		# 深拷贝以避免共享引用（每个资源拥有独立副本）
		var copy := AttributeData.new()
		copy.attribute = attr_data.attribute
		copy.value = attr_data.value
		copy.arithmetic_type = attr_data.arithmetic_type
		copy.modifier_name = attr_data.modifier_name
		attribute_defaults.append(copy)

## 虚方法：返回默认的 AttributeData 数组，子类应覆盖提供默认值
## 默认返回空数组
func _get_default_attribute_modifiers() -> Array[AttributeData]:
	return []
