extends Resource
class_name Card

@export var name:String
@export var type:String
var attributeModifiers:AttributeModifiers = AttributeModifiers.new()
var id:int


func get_attribute(attribute:StringName,value:int) -> int:
	return attributeModifiers.modify(attribute,value)

func serialize()->PackedByteArray:
	return CardSerializer.serialize(self)
	
static func deserialize(serialized_data: PackedByteArray) -> Object:
	return CardSerializer.deserialize(serialized_data)
