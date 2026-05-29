## 卡牌数据蓝图，定义卡牌的静态属性和默认行为。
@tool
extends ItemData
class_name CardData
## 卡牌名称（运行时不可变）
@export var name: StringName = &""
## 卡牌类型（运行时可变，初始值由蓝图提供）
@export var type: StringName = &"attack"

func _init() -> void:
	super._init()
	pack_class = HandCardPack

## 覆盖父类方法，提供卡牌默认属性修饰器
func _get_default_attribute_modifiers() -> Array[AttributeData]:
	var defaults: Array[AttributeData] = []
	var raw_defaults = {
		&"power": 3.0,
		&"cost": 1.0,
		&"attack_range": 1.0,
	}
	for attr: StringName in raw_defaults:
		var attr_data := AttributeData.new()
		attr_data.attribute = attr
		attr_data.value = raw_defaults[attr]
		attr_data.arithmetic_type = AttributeModifiers.TYPE_BASE_ADD
		attr_data.modifier_name = &"base_value"
		defaults.append(attr_data)
	return defaults
