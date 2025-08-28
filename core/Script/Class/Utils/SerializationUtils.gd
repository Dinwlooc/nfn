extends Object
class_name SerializationUtils

const INT16_BYTE_LEN:int = 2
const INT32_BYTE_LEN:int = 4
const MAX_STRING_LEN:int = 255
enum DeserMark {
	STRING = 255,
	INT32 = 254,
	VAR = 253,
	END = 252
}

class Data:
	var main_data: PackedByteArray
	var extra_data: PackedByteArray
	func _init(main_size: int):
		main_data.resize(main_size)
		extra_data = PackedByteArray()


static func serialize(obj:Object) -> PackedByteArray:
	if not (obj.has_method(&"get_enum_size") and obj.has_method(&"property_to_byte")):
		push_error("Object does not implement required serialization methods")
		return PackedByteArray()
	var serialize_data := Data.new(obj.get_enum_size())
	obj.property_to_byte(serialize_data)
	var all_data := PackedByteArray()
	all_data.resize(INT16_BYTE_LEN)
	all_data.encode_u16(0, serialize_data.main_data.size())
	all_data.append_array(serialize_data.main_data)
	all_data.append_array(serialize_data.extra_data)
	return all_data

static func serialize_write(key: int, value, serialize_data: Data) -> void:
	match typeof(value):
		TYPE_STRING:
			_serialize_string(key, value, serialize_data)
		TYPE_INT:
			_serialize_int(key, value, serialize_data)
		_:  # VAR类型
			_serialize_var(key, value, serialize_data)

static func _serialize_string(key: int, value: String, serialize_data: Data) -> void:
	serialize_data.main_data.set(key, DeserMark.STRING)
	var buffer: PackedByteArray = value.to_ascii_buffer()
	if buffer.size() > MAX_STRING_LEN:
		buffer.resize(MAX_STRING_LEN)
	serialize_data.extra_data.append(buffer.size())
	serialize_data.extra_data.append_array(buffer)

static func _serialize_int(key: int, value: int, serialize_data: Data) -> void:
	if value <= DeserMark.END and value >= 0:
		serialize_data.main_data.set(key, value)
	else:
		serialize_data.main_data.set(key, DeserMark.INT32)
		var pos := serialize_data.extra_data.size()
		serialize_data.extra_data.resize(pos + INT32_BYTE_LEN)
		serialize_data.extra_data.encode_s32(pos, value)

static func _serialize_var(key: int, value, serialize_data: Data) -> void:
	serialize_data.main_data.set(key, DeserMark.VAR)
	var buffer: PackedByteArray = var_to_bytes(value)
	serialize_data.extra_data.append(buffer.size() >> 8)
	serialize_data.extra_data.append(buffer.size() & 0xFF)
	serialize_data.extra_data.append_array(buffer)

static func deserialize(serialized_data: PackedByteArray) -> Array:
	var main_data_len := serialized_data.decode_u16(0)
	var ptr_main := INT16_BYTE_LEN  # 主数据起始位置
	var ptr_type := ptr_main + main_data_len  # 类型数据起始位置
	var output :Array= []
	output.resize(main_data_len)
	for idx in main_data_len:
		var mark := serialized_data[ptr_main]
		ptr_main += 1
		if mark <= DeserMark.END:  # 直接存储的值
			output[idx] = mark
		else:
			match mark:
				DeserMark.INT32:
					output[idx] = serialized_data.decode_s32(ptr_type)
					ptr_type += INT32_BYTE_LEN
				DeserMark.STRING:
					var str_len := serialized_data[ptr_type]
					ptr_type += 1
					var bytes := serialized_data.slice(ptr_type, ptr_type + str_len)
					output[idx] = bytes.get_string_from_ascii()
					ptr_type += str_len
				DeserMark.VAR:
					var var_len := serialized_data.decode_u16(ptr_type)
					ptr_type += INT16_BYTE_LEN
					var bytes := serialized_data.slice(ptr_type, ptr_type + var_len)
					output[idx] = bytes_to_var(bytes)
					ptr_type += var_len
	return output
