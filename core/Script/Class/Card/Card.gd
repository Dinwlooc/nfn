extends Resource
class_name Card

@export var name:String
@export var type:String
var attributeModifiers:AttributeModifiers = AttributeModifiers.new()
var id:int
const DESER_STR_MARK = 255

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
	#print(var_to_bytes(serialized_data))
	return var_to_bytes(serialized_data)
	
func get_enum_size()->int:
	#子类扩展枚举时需要覆盖它
	return BaseKeys.END

func serialize_2()->PackedByteArray:
	var main_data:PackedInt32Array
	var str_data:PackedStringArray
	main_data.resize(get_enum_size())
	serialize_write(BaseKeys.ID, id, main_data, str_data)
	serialize_write(BaseKeys.NAME, name, main_data, str_data)
	serialize_write(BaseKeys.TYPE, type, main_data, str_data)
	serialize_2_expand(main_data,str_data)
	var serialized_data:PackedByteArray = GlobalServer.PackedInt32Array_to_bytes_8(main_data)
	var slice_mark:int = serialized_data.size()
	serialized_data.append_array(GlobalServer.PackedStringArray_to_bytes_ascii(str_data))
	serialized_data.resize(serialized_data.size() + 2)
	serialized_data.encode_u16(serialized_data.size()-2,slice_mark)
	print(serialized_data)
	return serialized_data

func serialize_expand(serialized_data:Array)->Array:
	#子类的扩展
	serialized_data = serialize_expand_instance(serialized_data)
	return serialized_data

func serialize_2_expand(_main_data: PackedInt32Array, _str_data: PackedStringArray) -> void:
	pass

func serialize_expand_instance(_serialized_data:Array)->Array:
	#实例的扩展
	return _serialized_data
	
static func serialize_write(key: int, value, main_data: PackedInt32Array, str_data: PackedStringArray) -> void:
	match typeof(value):
		TYPE_STRING:
			main_data.set(key, DESER_STR_MARK)
			str_data.append(value)
		TYPE_INT:
			main_data.set(key, value)
		TYPE_FLOAT:
			push_warning("Float type not fully supported, casting to int: " + str(value))
			main_data.set(key, int(value))
		_:
			push_error("Unsupported type for key %s: %s" % [key, typeof(value)])
			main_data.set(key, 0)

static func deserialize(serialize_data:PackedByteArray)->Array:
	var data_dict = bytes_to_var(serialize_data)  # 反序列化数组，传输给渲染层时使用
	if not data_dict is Array:
		push_error("Invalid data format: Expected Dictionary")
		return []
	return data_dict

static func deserialize_2(serialized_data: PackedByteArray) -> Array:
	# 1. 检查数据长度有效性
	if serialized_data.size() < 2:
		push_error("Invalid data: Too short")
		return []
	var str_start_index:int = serialized_data.decode_u16(serialized_data.size()-2)
	if str_start_index >= serialized_data.size() - 2:
		push_error("Invalid string offset")
		return []
	var int_array:PackedInt32Array = GlobalServer.bytes_to_PackedByteArray_8(serialized_data.slice(0, str_start_index))
	var str_array:PackedStringArray = GlobalServer.bytes_to_PackedStringArray_ascii(serialized_data.slice(str_start_index, - 2))
	var str_index:int = 0  # 当前读取的字符串索引
	var output:Array = []
	for value in int_array:
		if value == DESER_STR_MARK:
			if str_index < str_array.size():
				output.append(str_array[str_index])
				str_index += 1
			else:
				output.append("")  # 防御性处理
				push_error("Missing string data")
		else:
			output.append(value)
	return output
