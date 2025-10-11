extends Resource
class_name Card

@export var name:StringName
@export var type:StringName
var id:int
var area_name:StringName
var attributeModifiers:AttributeModifiers = AttributeModifiers.new()

func get_attribute(attribute:StringName) -> int:
	return attributeModifiers.get_final_value(attribute)

func get_pack()->CardPack:
	var pack:CardPack = CardPack.new(id,name,type)
	return pack
