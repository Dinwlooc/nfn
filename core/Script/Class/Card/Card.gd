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
	

func serialize()->PackedByteArray:
	var serialized_data:Array
	serialized_data.resize(get_enum_size())
	serialized_data.set(BaseKeys.ID,id)
	serialized_data.set(BaseKeys.NAME,name)
	serialized_data.set(BaseKeys.TYPE,type)
	serialize_expand(serialized_data)
	return var_to_bytes(serialized_data)
	
func get_enum_size()->int:
	#子类扩展枚举时需要覆盖它
	return BaseKeys.END
	
func serialize_expand(serialized_data:Array)->Array:
	#子类的扩展
	serialized_data = serialize_expand_instance(serialized_data)
	return serialized_data

func serialize_expand_instance(serialized_data:Array)->Array:
	#实例的扩展
	return serialized_data

static func deserialize(serialize_data:PackedByteArray)->Array:
	var data_dict = bytes_to_var(serialize_data)  # 反序列化数组，传输给渲染层时使用
	if not data_dict is Array:
		push_error("Invalid data format: Expected Dictionary")
		return []
	return data_dict
