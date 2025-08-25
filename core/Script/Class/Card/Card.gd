extends Resource
class_name Card

@export var name:String
@export var type:String
var attributeModifiers:AttributeModifiers = AttributeModifiers.new()
var id:int
const INT16_BYTE_LEN:int = 2
const INT32_BYTE_LEN:int = 4
enum DeserMark {
	STRING = 255,
	INT32 = 254,
	END = 253
}

enum BaseKeys {
	ID ,
	NAME ,
	TYPE ,
	END #用于调整子类枚举的标识符
}
enum DataTypeMask{
	STRING = 1,
	INT32 = 2,
}
enum DataTypeKeys{
	MAIN = 0,
	STRING,
	INT32,
	END
}
const TYPE_NUM = DataTypeKeys.END-1

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
	var int32_data:PackedByteArray = serialize_array.get(DataTypeKeys.INT32)
	var all_data:PackedByteArray
	all_data.append_array(main_data)
	var sub_data:PackedByteArray
	var p_sub_data:int = 0 #字节偏移量
	var type_mask:int = 0
	sub_data.resize(INT16_BYTE_LEN * (DataTypeKeys.END) - 1 )
	#逆序写入类型数据
	if int32_data:
		sub_data.encode_u16(p_sub_data,int32_data.size())
		all_data.append_array(int32_data)
		p_sub_data += INT16_BYTE_LEN
		type_mask += DataTypeMask.INT32
	if str_data:
		sub_data.encode_u16(p_sub_data,str_data.size())
		all_data.append_array(str_data)
		p_sub_data += INT16_BYTE_LEN
		type_mask += DataTypeMask.STRING
	sub_data.encode_u8(p_sub_data,type_mask) #类型掩码
	sub_data.resize(p_sub_data+1) #裁剪空值
	all_data.append_array(sub_data)
	# 主数据 | 类型数据 | 切片标记 | 掩码
	return all_data

func property_to_byte(serialize_array:Array[PackedByteArray])->void:
	serialize_write(BaseKeys.ID, id, serialize_array)
	serialize_write(BaseKeys.NAME, name, serialize_array)
	serialize_write(BaseKeys.TYPE, type, serialize_array)
	 # 子类可以重写



static func serialize_write(key: int, value, serialize_array:Array[PackedByteArray]) -> void:
	match typeof(value):
		TYPE_STRING:
			serialize_array.get(DataTypeKeys.MAIN).set(key,DeserMark.STRING)
			var buffer:PackedByteArray = value.to_ascii_buffer()
			buffer.append(0)
			serialize_array.get(DataTypeKeys.STRING).append_array(buffer)
			return
		TYPE_INT:
			if (value <= DeserMark.END && value>=0):
					serialize_array.get(DataTypeKeys.MAIN).set(key,value)
			else:
					serialize_array.get(DataTypeKeys.MAIN).set(key,DeserMark.INT32)
					var origin_size:int = serialize_array.get(DataTypeKeys.INT32).size()
					serialize_array.get(DataTypeKeys.INT32).resize(origin_size+INT32_BYTE_LEN)
					serialize_array.get(DataTypeKeys.INT32).encode_s32(origin_size,value) #和godot内置方法一致，使用s32

static func deserialize(serialized_data: PackedByteArray) -> Array:
	if serialized_data.size() < 1:
		push_error("Invalid data: Too short")
		return []	
	#0、逆序读取。
	var ptr_end:int = serialized_data.size() - 1
	#1、获取掩码，逐一生成不定长的切片标记数组
	var mask:int = serialized_data[ptr_end]
	var slice_array:PackedInt32Array = []
	slice_array.resize(TYPE_NUM)
	for bit_index in TYPE_NUM:
		if mask & (1 << bit_index):
			ptr_end -= INT16_BYTE_LEN
			var len_val:int = serialized_data.decode_u16(ptr_end)
			slice_array.set(bit_index,len_val)
	#2、利用切片标记分割数组，分类暂存
	var str_arr:PackedStringArray #godot不原生支持反序列化
	var int32_arr:PackedInt32Array# godot自带反序列化
	for i in TYPE_NUM:
		if slice_array[i] != 0:
			var ptr_start:int = ptr_end - slice_array[i]
			match i+1:
				DataTypeKeys.STRING:
					str_arr = GlobalServer.bytes_to_PackedStringArray_ascii(serialized_data.slice(ptr_start, ptr_end))
				DataTypeKeys.INT32:
					int32_arr = serialized_data.slice(ptr_start, ptr_end).to_int32_array()
			ptr_end = ptr_start
	var main_data_array:PackedByteArray = serialized_data.slice(0, ptr_end)
	#3、生成渲染层数据数组
	var str_index:int = 0
	var int32_index:int = 0
	var output:Array = []
	output.resize(main_data_array.size())
	for i in main_data_array.size():
		var value = main_data_array[i]
		if value == DeserMark.STRING:
			if str_arr:
				output.set(i,str_arr[str_index])
				str_index += 1
			else:
				output.set(i,"")
				push_error("Missing string data at index:",i)
		elif value == DeserMark.INT32:
			if int32_arr:
				output.set(i,int32_arr[int32_index])
				int32_index += 1
			else:
				output.set(i,"")
				push_error("Missing int32 data at index:",i)
		else:
			output.set(i,value)
	return output #渲染层不重建Card类，只返回数组。
