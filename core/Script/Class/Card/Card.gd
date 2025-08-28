extends Resource
class_name Card

@export var name:String
@export var type:String
var attributeModifiers:AttributeModifiers = AttributeModifiers.new()
var id:int
enum BaseKeys {
	ID ,
	NAME ,
	TYPE ,
	END #用于调整子类枚举的标识符
}

func get_attribute(attribute:StringName,value:int) -> int:
	return attributeModifiers.modify(attribute,value)
	
func get_enum_size()->int:
	#子类扩展枚举时需要覆盖它
	return BaseKeys.END
	
func property_to_byte(serialize_data:SerializationUtils.Data)->void:
	serialize_write(BaseKeys.ID, id, serialize_data)
	serialize_write(BaseKeys.NAME, name, serialize_data)
	serialize_write(BaseKeys.TYPE, type, serialize_data)
	 # 子类可以重写

func serialize()->PackedByteArray:
	return SerializationUtils.serialize(self)
	
static func deserialize(serialized_data: PackedByteArray) -> Array:
	return SerializationUtils.deserialize(serialized_data)

static func serialize_write(key: int, value, serialize_data:SerializationUtils.Data):
	SerializationUtils.serialize_write(key, value, serialize_data)
