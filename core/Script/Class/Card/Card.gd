extends Resource
class_name Card

@export var name:String
@export var type:String
var attributeModifiers:AttributeModifiers = AttributeModifiers.new()
var id:int
enum DeserMark {
	STRING = 255
}

enum BaseKeys {
	ID ,
	NAME ,
	TYPE ,
	END #用于调整子类枚举的标识符
}
enum DataTypeMask{
	STRING = 1,
	
}
enum DataTypeKeys{
	MAIN = 0,
	STRING,
	END
}

func get_attribute(attribute:StringName,value:int) -> int:
	return attributeModifiers.modify(attribute,value)
	
	
func get_enum_size()->int:
	#子类扩展枚举时需要覆盖它
	return BaseKeys.END

func serialize()->PackedByteArray:
	var serialize_array:Array[PackedByteArray]
	serialize_array.resize(DataTypeKeys.END)
	var main_data:PackedByteArray = serialize_array.get(DataTypeKeys.MAIN)
	main_data.resize(get_enum_size())
	property_to_byte(serialize_array)
	var str_data:PackedByteArray = serialize_array.get(DataTypeKeys.STRING)
	var all_data:PackedByteArray
	all_data.append_array(main_data)
	var sub_data:PackedByteArray
	var p_sub_data:int = 0 #字节偏移量
	var type_mask:int = 0
	sub_data.resize(2 * (DataTypeKeys.END) - 1 )
	if str_data:
		sub_data.encode_u16(p_sub_data,str_data.size())
		all_data.append_array(str_data)
		p_sub_data += 2
		type_mask += DataTypeMask.STRING
	sub_data.encode_u8(p_sub_data,type_mask) #类型掩码
	sub_data.resize(p_sub_data+1)
	all_data.append_array(sub_data)
	return all_data

func property_to_byte(serialize_array:Array[PackedByteArray])->void:
	serialize_write(BaseKeys.ID, id, serialize_array)
	serialize_write(BaseKeys.NAME, name, serialize_array)
	serialize_write(BaseKeys.TYPE, type, serialize_array)
	pass # 子类可以重写
	return


static func serialize_write(key: int, value, serialize_array:Array[PackedByteArray]) -> void:
	match typeof(value):
		TYPE_STRING:
			serialize_array.get(DataTypeKeys.MAIN).encode_u8(key,DeserMark.STRING)
			var buffer:PackedByteArray = value.to_ascii_buffer()
			buffer.append(0)
			serialize_array.get(DataTypeKeys.STRING).append_array(buffer)
			return
		TYPE_INT:
			match 1 | int(value > 254) | (int(value > 0xFFFF) << 1):
				1:
					serialize_array.get(DataTypeKeys.MAIN).encode_u8(key,value)
					return
				2:
					return
				3:
					return
		_:
			return

static func deserialize(serialized_data: PackedByteArray) -> Array:
	if serialized_data.size() < 1:
		push_error("Invalid data: Too short")
		return []
	var ptr_end:int = serialized_data.size() - 1
	var mask:int = serialized_data[ptr_end]
	var slice_array:PackedInt32Array = []
	const TYPE_NUM = DataTypeKeys.END-1
	slice_array.resize(TYPE_NUM)
	for bit_index in range(8):
		if mask & (1 << bit_index):
			ptr_end -= 2
			var len_val:int = serialized_data.decode_u16(ptr_end)
			slice_array.set(bit_index,len_val)
	# 按掩码顺序获取数据切片
	var str_arr:PackedStringArray
	for i in range(TYPE_NUM-1,-1,-1):
		if slice_array[i] != 0:
			var ptr_start:int = ptr_end - slice_array[i]
			match i+1:
				DataTypeKeys.STRING:
					str_arr = GlobalServer.bytes_to_PackedStringArray_ascii(serialized_data.slice(ptr_start, ptr_end))
			ptr_end = ptr_start
	var main_data_array:PackedByteArray = serialized_data.slice(0, ptr_end)
	var output:Array = []
	output.resize(main_data_array.size())
	for i in range(main_data_array.size()-1,-1,-1):
		var value = main_data_array[i]
		if value == DeserMark.STRING:
			if str_arr:
				output.set(i,str_arr[-1])
				str_arr.resize(str_arr.size()-1)
			else:
				output.set(i,"")
				push_error("Missing string data at index:",i)
		else:
			output.set(i,value)
	return output
