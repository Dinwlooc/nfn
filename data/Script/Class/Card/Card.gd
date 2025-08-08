extends Resource
class_name Card

@export var name:String
@export var type:String
var attributeModifiers:AttributeModifiers = AttributeModifiers.new()
var id:int

func get_attribute(attribute: String) -> int:
	return attributeModifiers.modify(attribute,self.get(attribute))

func serialize()->PackedByteArray:
	var serialized_data:Dictionary
	serialized_data.set("id",id)
	serialized_data.set("name",name)
	serialized_data.set("type",type)
	serialize_expand(serialized_data)
	return var_to_bytes(serialized_data)
	
func serialize_expand(serialized_data:Dictionary)->Dictionary:
	#子类的扩展
	serialized_data = serialize_expand_instance(serialized_data)
	return serialized_data

func serialize_expand_instance(serialized_data:Dictionary)->Dictionary:
	#实例的扩展
	return serialized_data

static func deserialize(serialize_data:PackedByteArray)->Dictionary:
	var data_dict = bytes_to_var(serialize_data)  # 反序列化字典，传输给渲染层时使用
	# 验证数据有效性
	if not data_dict is Dictionary:
		push_error("Invalid data format: Expected Dictionary")
		return {}
	return data_dict
