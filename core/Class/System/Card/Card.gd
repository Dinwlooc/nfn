extends Resource
class_name Card

@export var name:StringName
@export var type:StringName
var id:int
var area_name:StringName
var attributeModifiers:AttributeModifiers = AttributeModifiers.new()

func get_attribute(attribute:StringName,value:int = get(attribute) ) -> int:
	if !value:
		push_error("Error:Missing value")
		return 0
	return attributeModifiers.modify(attribute,value)

func get_pack()->CardPack:
	var pack:CardPack = CardPack.new(id,name,type)
	return pack
