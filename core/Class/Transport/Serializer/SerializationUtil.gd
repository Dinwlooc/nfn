extends RefCounted
class_name SerializationUtil

const VARINT_MASK: int = 0x7F
const VARINT_CONTINUE_FLAG: int = 0x80

# 基础类型写入（自动类型判断）
static func write(buffer: StreamPeerBuffer, value) -> void:
	match typeof(value):
		TYPE_STRING:
			_write_string(buffer, value)
		TYPE_INT:
			_write_varint(buffer, value)
		TYPE_STRING_NAME:
			_write_string(buffer, String(value))
		TYPE_FLOAT:
			buffer.put_double(value)
		TYPE_PACKED_BYTE_ARRAY:  # 新增字节数组支持
			_write_packed_byte_array(buffer, value)
		TYPE_PACKED_INT32_ARRAY:
			_write_packed_int_array(buffer,value)
		TYPE_PACKED_INT64_ARRAY:
			_write_packed_int_array(buffer,value)
		_:
			buffer.put_var(value)

# 基础类型读取（需指定类型）
static func read(buffer: StreamPeerBuffer, type: int)->Variant:
	match type:
		TYPE_STRING:
			return _read_string(buffer)
		TYPE_INT:
			return _read_varint(buffer)
		TYPE_STRING_NAME:
			return StringName(_read_string(buffer))
		TYPE_FLOAT:
			return buffer.get_double()
		TYPE_PACKED_BYTE_ARRAY:  # 新增字节数组支持
			return _read_packed_byte_array(buffer)
		TYPE_PACKED_INT32_ARRAY:
			return _read_packed_int32_array(buffer)
		TYPE_PACKED_INT64_ARRAY:
			return _read_packed_int64_array(buffer)
		_:
			return buffer.get_var()

# 使用标准ZigZag编码的变长整数
static func _write_varint(buffer: StreamPeerBuffer, value: int) -> void:
	var zigzag = (value << 1) ^ (value >> 63)
	var unsigned = zigzag if zigzag >= 0 else (1 << 64) + zigzag
	while unsigned >= VARINT_CONTINUE_FLAG:
		buffer.put_u8((unsigned & VARINT_MASK) | VARINT_CONTINUE_FLAG)
		unsigned = unsigned >> 7
	buffer.put_u8(unsigned)

# ZigZag解码
static func _read_varint(buffer: StreamPeerBuffer) -> int:
	var result = 0
	var shift = 0
	var byte: int
	for i in range(10):
		byte = buffer.get_u8()
		result |= (byte & VARINT_MASK) << shift
		shift += 7
		if (byte & VARINT_CONTINUE_FLAG) == 0:
			break
	var _sign:int = (result & 1) * -2 + 1  # 0->1, 1->-1
	return (result >> 1) * _sign

# 字符串序列化（保持不变）
static func _write_string(buffer: StreamPeerBuffer, value: String) -> void:
	var utf8_bytes = value.to_utf8_buffer()
	var _len = utf8_bytes.size()
	_write_varint(buffer, _len)
	if _len > 0:
		buffer.put_data(utf8_bytes)

# 字符串反序列化（保持不变）
static func _read_string(buffer: StreamPeerBuffer) -> String:
	var _len = _read_varint(buffer)
	if _len == 0:
		return ""
	var result = buffer.get_utf8_string(_len)
	return result if result else ""

static func _write_packed_int_array(buffer: StreamPeerBuffer, array) -> void:
	_write_varint(buffer, array.size())
	for i in range(array.size()):
		_write_varint(buffer, array[i])

# 反序列化 PackedInt32Array
static func _read_packed_int32_array(buffer: StreamPeerBuffer) -> PackedInt32Array:
	var size = _read_varint(buffer)
	var arr = PackedInt32Array()
	arr.resize(size)
	for i in range(size):
		arr[i] = _read_varint(buffer)  # 自动截断为32位
	return arr

# 反序列化 PackedInt64Array
static func _read_packed_int64_array(buffer: StreamPeerBuffer) -> PackedInt64Array:
	var size = _read_varint(buffer)
	var arr = PackedInt64Array()
	arr.resize(size)
	for i in range(size):
		arr[i] = _read_varint(buffer)
	return arr

static func _write_packed_byte_array(buffer: StreamPeerBuffer, array: PackedByteArray) -> void:
	_write_varint(buffer, array.size())
	if array.size() > 0:
		buffer.put_data(array)
# 新增：紧凑字节数组读取
static func _read_packed_byte_array(buffer: StreamPeerBuffer) -> PackedByteArray:
	var size = _read_varint(buffer)
	if size == 0:
		return PackedByteArray()
	return buffer.get_data(size)[1]
# 辅助功能保持不变
static func serialize_to_bytes(value) -> PackedByteArray:
	var buffer = StreamPeerBuffer.new()
	buffer.big_endian = true
	write(buffer, value)
	return buffer.data_array

static func deserialize_from_bytes(bytes: PackedByteArray, type: int):
	var buffer = StreamPeerBuffer.new()
	buffer.big_endian = true
	buffer.put_data(bytes)
	buffer.seek(0)
	return read(buffer, type)
