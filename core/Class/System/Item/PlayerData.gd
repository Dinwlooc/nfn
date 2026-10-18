## 玩家数据蓝图，定义玩家的静态属性和默认行为。
@tool
extends ItemData
class_name PlayerData

## 构造：指定玩家数据包类型
func _init() -> void:
	super._init()
	pack_class = PlayerPack

## 覆盖父类方法，提供玩家默认属性
func _get_default_attribute_modifiers() -> Array[AttributeData]:
	var defaults: Array[AttributeData] = []
	var raw_defaults = {
		&"HP_max": 20.0,
		&"MP_max": 20.0,
		&"init_AP": 3.0,
		&"draw_cards_count": 2.0,
		&"speed": 1.0,
	}
	for attr: StringName in raw_defaults:
		var attr_data := AttributeData.new()
		attr_data.attribute = attr
		attr_data.value = raw_defaults[attr]
		attr_data.arithmetic_type = AttributeModifiers.TYPE_BASE_ADD
		attr_data.modifier_name = &"base_value"
		defaults.append(attr_data)
	return defaults
