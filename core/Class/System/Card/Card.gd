extends Resource
class_name Card

@export var name:StringName
@export var type:StringName
var id:int
var attributeModifiers:AttributeModifiers = AttributeModifiers.new()

func get_attribute(attribute:StringName,value:int = get(attribute) ) -> int:
	if !value:
		push_error("Error:Missing value")
		return 0
	return attributeModifiers.modify(attribute,value)

func serialize()->PackedByteArray:
	return CardSerializer.serialize(self)
	
static func deserialize(serialized_data: PackedByteArray) -> RenderPack.CardData :
	return CardSerializer.deserialize(serialized_data)
