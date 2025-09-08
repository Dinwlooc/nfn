extends RefCounted
class_name BaseSerializer
#前置序列化工具类
const MAX_STRING_LEN:int = 255
enum DeserMark {
	STRING = 255,
	INT32 = 254,
	VAR = 253,
	END = 252
}
class Data:
	var main_data: PackedByteArray
	var extra_buffer: StreamPeerBuffer 
	func _init(main_size: int):
		main_data.resize(main_size)
		extra_buffer = StreamPeerBuffer.new()
		extra_buffer.big_endian = true  # 大端字节序
static func data_to_byte(data:Data) -> PackedByteArray:
	var all_buffer := StreamPeerBuffer.new()
	all_buffer.big_endian = true
	all_buffer.put_u16(data.main_data.size())
	all_buffer.put_data(data.main_data)
	all_buffer.put_data(data.extra_buffer.get_data_array())
	return all_buffer.get_data_array()

static func serialize_write(key: int, value, serialize_data: Data) -> void:
	match typeof(value):
		TYPE_STRING:
			_serialize_string(key, value, serialize_data)
		TYPE_INT:
			_serialize_int(key, value, serialize_data)
		TYPE_STRING_NAME:
			_serialize_string(key, String(value), serialize_data)
		_:  # VAR类型
			_serialize_var(key, value, serialize_data)

static func _serialize_string(key: int, value: String, serialize_data: Data) -> void:
	serialize_data.main_data.set(key, DeserMark.STRING)
	var buffer: PackedByteArray = value.to_ascii_buffer()
	if buffer.size() > MAX_STRING_LEN:
		buffer.resize(MAX_STRING_LEN)
	serialize_data.extra_buffer.put_u8(buffer.size())  # 字符串长度(1字节)
	serialize_data.extra_buffer.put_data(buffer)

static func _serialize_int(key: int, value: int, serialize_data: Data) -> void:
	if value <= DeserMark.END and value >= 0:
		serialize_data.main_data.set(key, value)
	else:
		serialize_data.main_data.set(key, DeserMark.INT32)
		serialize_data.extra_buffer.put_32(value)

static func _serialize_var(key: int, value, serialize_data: Data) -> void:
	serialize_data.main_data.set(key, DeserMark.VAR)
	var buffer: PackedByteArray = var_to_bytes(value)
	serialize_data.extra_buffer.put_u16(buffer.size())  # 数据长度(2字节)
	serialize_data.extra_buffer.put_data(buffer)

static func byte_to_data_array(serialized_data: PackedByteArray) -> Array:
	var stream := StreamPeerBuffer.new()
	stream.big_endian = true
	stream.put_data(serialized_data)
	stream.seek(0)  # 重置读取位置
	var main_data_len := stream.get_u16()
	var main_data := stream.get_data(main_data_len)
	if main_data[0] != OK:
		push_error("读取主数据失败")
		return []
	main_data = main_data[1]  # 提取实际数据
	var output := []
	output.resize(main_data_len)
	for idx in main_data_len:
		var mark: int = main_data[idx]
		if mark <= DeserMark.END:
			output[idx] = mark
		else:
			match mark:
				DeserMark.INT32:
					output[idx] = stream.get_32()  # 直接读取4字节整数
				DeserMark.STRING:
					var str_len := stream.get_u8()  # 读取长度(1字节)
					var str_data = stream.get_data(str_len)
					if str_data[0] == OK:
						output[idx] = str_data[1].get_string_from_ascii()
					else:
						output[idx] = ""
				DeserMark.VAR:
					var var_len := stream.get_u16()  # 读取长度(2字节)
					var var_data = stream.get_data(var_len)
					if var_data[0] == OK:
						output[idx] = bytes_to_var(var_data[1])
					else:
						output[idx] = null
	return output
