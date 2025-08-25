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

func serialize()->PackedByteArray:
	return static_serialize(self)
	
func property_to_byte(serialize_data:SerializeData)->void:
	serialize_write(BaseKeys.ID, id, serialize_data)
	serialize_write(BaseKeys.NAME, name, serialize_data)
	serialize_write(BaseKeys.TYPE, type, serialize_data)
	 # 子类可以重写

const INT16_BYTE_LEN:int = 2
const INT32_BYTE_LEN:int = 4
enum DeserMark {
	STRING = 255,
	INT32 = 254,
	VAR = 253,
	END = 252
}
enum DataTypeMask{
	STRING = 1,
	INT32 = 2,
	VAR = 4
}
enum DataTypeKeys{
	MAIN = 0,
	STRING,
	INT32,
	VAR,
	END
}
const TYPE_NUM = DataTypeKeys.END-1

class SerializeData:
	var main_data:PackedByteArray
	var str_data:PackedByteArray
	var int32_data:PackedByteArray
	var var_data:Array

static func static_serialize(card:Card)->PackedByteArray:
	var serialize_data := SerializeData.new()
	serialize_data.main_data.resize(card.get_enum_size())
	card.property_to_byte(serialize_data)
	var all_data:PackedByteArray
	all_data.append_array(serialize_data.main_data)
	var sub_data:PackedByteArray
	var p_sub_data:int = 0 #字节偏移量
	var type_mask:int = 0
	sub_data.resize(INT16_BYTE_LEN * (DataTypeKeys.END) - 1 )
	#逆序写入类型数据
	if serialize_data.var_data:
		var buffer:PackedByteArray = var_to_bytes(serialize_data.var_data)
		sub_data.encode_u16(p_sub_data,buffer.size())
		all_data.append_array(buffer)
		p_sub_data += INT16_BYTE_LEN
		type_mask += DataTypeMask.VAR
	if serialize_data.int32_data:
		sub_data.encode_u16(p_sub_data,serialize_data.int32_data.size())
		all_data.append_array(serialize_data.int32_data)
		p_sub_data += INT16_BYTE_LEN
		type_mask += DataTypeMask.INT32
	if serialize_data.str_data:
		sub_data.encode_u16(p_sub_data,serialize_data.str_data.size())
		all_data.append_array(serialize_data.str_data)
		p_sub_data += INT16_BYTE_LEN
		type_mask += DataTypeMask.STRING

	sub_data.encode_u8(p_sub_data,type_mask) #类型掩码
	sub_data.resize(p_sub_data+1) #裁剪空值
	all_data.append_array(sub_data)
	# 主数据 | 类型数据 | 切片标记 | 掩码
	return all_data

static func serialize_write(key: int, value, serialize_data:SerializeData) -> void:
	match typeof(value):
		TYPE_STRING: #规范：255长度以内的纯ASCII字符。
			serialize_data.main_data.set(key,DeserMark.STRING)
			var buffer:PackedByteArray = value.to_ascii_buffer()
			if buffer.size() > 255:
				buffer.resize(255)
			serialize_data.str_data.append(buffer.size())  # 写入长度前缀
			serialize_data.str_data.append_array(buffer)
		TYPE_INT:
			if (value <= DeserMark.END && value>=0):
					serialize_data.main_data.set(key,value)
			else:
					serialize_data.main_data.set(key,DeserMark.INT32)
					var origin_size:int = serialize_data.int32_data.size()
					serialize_data.int32_data.resize(origin_size+INT32_BYTE_LEN)
					serialize_data.int32_data.encode_s32(origin_size,value) #和godot内置方法一致，使用s32
		_:
			serialize_data.main_data.set(key,DeserMark.VAR)
			serialize_data.var_data.append(value)

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
			slice_array.set(bit_index,len_val) #与掩码顺序相同的正序顺序
	#2、利用切片标记分割数组，分类暂存
	var str_arr:PackedStringArray #godot不原生支持反序列化
	var int32_arr:PackedInt32Array# godot自带反序列化
	var var_arr:Array
	for i in TYPE_NUM:
		if slice_array[i] != 0:
			var ptr_start:int = ptr_end - slice_array[i]
			match i+1:
				DataTypeKeys.STRING:
					str_arr = bytes_to_strings(serialized_data.slice(ptr_start, ptr_end))
				DataTypeKeys.INT32:
					int32_arr = serialized_data.slice(ptr_start, ptr_end).to_int32_array()
				DataTypeKeys.VAR:
					var_arr = bytes_to_var(serialized_data.slice(ptr_start, ptr_end))
			ptr_end = ptr_start
	var main_data_array:PackedByteArray = serialized_data.slice(0, ptr_end)
	#3、生成渲染层数据数组
	var str_index:int = 0
	var int32_index:int = 0
	var var_index:int = 0
	var output:Array = []
	output.resize(main_data_array.size())
	for i in main_data_array.size():
		var value = main_data_array[i]
		if value <= DeserMark.END:
			output.set(i,value)
		elif value == DeserMark.STRING:
			if str_arr:
				output.set(i,StringName(str_arr[str_index]))
				str_index += 1
			else:
				output.set(i,&"")
				push_error("Missing string data at index:",i)
		elif value == DeserMark.INT32:
			if int32_arr:
				output.set(i,int32_arr[int32_index])
				int32_index += 1
			else:
				output.set(i,0)
				push_error("Missing int32 data at index:",i)
		elif value == DeserMark.VAR:
			if var_arr:
				output.set(i,var_arr[var_index])
				var_index += 1
	return output #渲染层不重建Card类，只返回数组。

static func bytes_to_strings(data: PackedByteArray) -> PackedStringArray:
	var result := PackedStringArray()
	var idx := 0
	while idx < data.size():
		var len := data.decode_u8(idx) as int
		idx += 1
		result.append(data.slice(idx, idx + len).get_string_from_utf8())
		idx += len
	return result
