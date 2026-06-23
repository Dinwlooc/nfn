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
		TYPE_BOOL:
			_write_bool(buffer, value)
		TYPE_PACKED_BYTE_ARRAY:
			_write_packed_byte_array(buffer, value)
		TYPE_PACKED_INT32_ARRAY:
			_write_packed_int_array(buffer, value)
		TYPE_PACKED_INT64_ARRAY:
			_write_packed_int_array(buffer, value)
		TYPE_DICTIONARY:
			write_dictionary(buffer, value)
		_:
			assert(false, "试图序列化此工具不支持的类型。建议使用其他工具。")
			buffer.put_var(value)

# 基础类型读取（需指定类型）
static func read(buffer: StreamPeerBuffer, type: int) -> Variant:
	match type:
		TYPE_STRING:
			return _read_string(buffer)
		TYPE_INT:
			return _read_varint(buffer)
		TYPE_STRING_NAME:
			return StringName(_read_string(buffer))
		TYPE_FLOAT:
			return buffer.get_double()
		TYPE_BOOL:
			return _read_bool(buffer)
		TYPE_PACKED_BYTE_ARRAY:
			return _read_packed_byte_array(buffer)
		TYPE_PACKED_INT32_ARRAY:
			return _read_packed_int32_array(buffer)
		TYPE_PACKED_INT64_ARRAY:
			return _read_packed_int64_array(buffer)
		TYPE_DICTIONARY:
			return read_dictionary(buffer)
		_:
			return buffer.get_var()
# ---- 写入变长整数（Zigzag编码） ----
## 写入一个有符号64位整数，采用 Zigzag + Varint 编码。
## 对于绝大多数值（除 -2^63），使用算术右移安全高效。
static func _write_varint(buffer: StreamPeerBuffer, value: int) -> void:
	var zigzag: int = (value << 1) ^ (value >> 63)
	if zigzag < 0:
		_write_extreme_negative(buffer)  # 独立处理
		return
	while zigzag >= VARINT_CONTINUE_FLAG:
		buffer.put_u8((zigzag & VARINT_MASK) | VARINT_CONTINUE_FLAG)
		zigzag = zigzag >> 7
	buffer.put_u8(zigzag)
## 专门处理 value = -2^63 时的编码
## 该值 Zigzag 后为 -1，其 varint 编码固定为 9 个 0xFF + 1 个 0x01
static func _write_extreme_negative(buffer: StreamPeerBuffer) -> void:
	for _i in range(9):
		buffer.put_u8(0xFF)   # 带继续标志
	buffer.put_u8(0x01)       # 结束字节
# ---- 读取变长整数（Zigzag解码） ----
## 读取一个 varint 并解码为有符号64位整数。
## 当解析出的无符号数 >= 2^63 时，GDScript 中表现为负数，
## 解码最后一步需进行逻辑右移，此时调用独立函数处理。
static func _read_varint(buffer: StreamPeerBuffer) -> int:
	var result: int = 0
	var shift: int = 0
	var byte: int
	for _i in range(10):
		byte = buffer.get_u8()
		result |= (byte & VARINT_MASK) << shift
		shift += 7
		if (byte & VARINT_CONTINUE_FLAG) == 0:
			break
	if result < 0:
		return _decode_extreme(result)   # 独立处理
	return (result >> 1) ^ (-(result & 1))
## 专门处理 result < 0（即无符号值 >= 2^63）时的解码
## 此时需将 result 视为无符号数，对其进行逻辑右移 1 位，
## 然后按 Zigzag 规则还原符号。
static func _decode_extreme(result: int) -> int:
	var shifted: int = (result & 0x7FFFFFFFFFFFFFFF) >> 1
	return shifted ^ (-(result & 1))
## 字符串序列化：长度前缀 + UTF‑8 数据
static func _write_string(buffer: StreamPeerBuffer, value: String) -> void:
	var utf8_bytes = value.to_utf8_buffer()
	var _len = utf8_bytes.size()
	_write_varint(buffer, _len)
	if _len > 0:
		buffer.put_data(utf8_bytes)

## 字符串反序列化
static func _read_string(buffer: StreamPeerBuffer) -> String:
	var _len = _read_varint(buffer)
	if _len == 0:
		return ""
	var result = buffer.get_utf8_string(_len)
	return result if result else ""

## 将布尔值写为单字节（0 或 1）
static func _write_bool(buffer: StreamPeerBuffer, value: bool) -> void:
	buffer.put_u8(1 if value else 0)

## 从单字节读取布尔值
static func _read_bool(buffer: StreamPeerBuffer) -> bool:
	return buffer.get_u8() != 0

## 写入紧缩整数数组（PackedInt32Array 或 PackedInt64Array），统一用 varint 编码每个元素
static func _write_packed_int_array(buffer: StreamPeerBuffer, array) -> void:
	_write_varint(buffer, array.size())
	for i in range(array.size()):
		_write_varint(buffer, array[i])

## 反序列化 PackedInt32Array
static func _read_packed_int32_array(buffer: StreamPeerBuffer) -> PackedInt32Array:
	var size = _read_varint(buffer)
	var arr = PackedInt32Array()
	arr.resize(size)
	for i in range(size):
		arr[i] = _read_varint(buffer)
	return arr

## 反序列化 PackedInt64Array
static func _read_packed_int64_array(buffer: StreamPeerBuffer) -> PackedInt64Array:
	var size = _read_varint(buffer)
	var arr = PackedInt64Array()
	arr.resize(size)
	for i in range(size):
		arr[i] = _read_varint(buffer)
	return arr

## 写入 PackedByteArray：长度前缀 + 原始字节数据
static func _write_packed_byte_array(buffer: StreamPeerBuffer, array: PackedByteArray) -> void:
	_write_varint(buffer, array.size())
	if array.size() > 0:
		buffer.put_data(array)

## 紧凑读取 PackedByteArray：先读长度，再读指定字节数
static func _read_packed_byte_array(buffer: StreamPeerBuffer) -> PackedByteArray:
	var size = _read_varint(buffer)
	if size == 0:
		return PackedByteArray()
	return buffer.get_data(size)[1]

## 泛型写入：先写入 varint 类型枚举，再委托给 [method write] 写入值数据
static func generic_write(buffer: StreamPeerBuffer, value: Variant) -> void:
	var type_id: int = typeof(value)
	_write_varint(buffer, type_id)
	write(buffer, value)

## 泛型读取：先读取 varint 类型枚举，再用该类型调用 [method read] 恢复值
static func generic_read(buffer: StreamPeerBuffer) -> Variant:
	var type_id: int = _read_varint(buffer)
	return read(buffer, type_id)

# 序列化字典：先写总数，为零结束；总数 ≤5 时逐对写键值变体，否则按分组写入
static func write_dictionary(buffer: StreamPeerBuffer, dict: Dictionary[StringName, Variant]) -> void:
	var total: int = dict.size()
	_write_varint(buffer, total)
	if total == 0:
		return
	if total <= 5:
		_write_small_dict_entries(buffer, dict)
		return
	var groups: Array[Dictionary] = _classify_dict_entries(dict)
	_write_group_int(buffer, groups[0])
	_write_group_float(buffer, groups[1])
	_write_group_string(buffer, groups[2])
	_write_group_bool(buffer, groups[3])
	_write_group_other(buffer, groups[4])

## 反序列化字典：先读总数，为零返回空；总数 ≤5 时逐对读取键值变体，否则按分组读取
static func read_dictionary(buffer: StreamPeerBuffer) -> Dictionary[StringName, Variant]:
	var total: int = _read_varint(buffer)
	if total == 0:
		return {}
	if total <= 5:
		return _read_small_dict_entries(buffer, total)
	var dict: Dictionary[StringName, Variant] = {}
	var processed: int = 0
	processed += _read_group_int(buffer, dict)
	processed += _read_group_float(buffer, dict)
	processed += _read_group_string(buffer, dict)
	processed += _read_group_bool(buffer, dict)
	var other_count: int = total - processed
	if other_count > 0:
		_read_group_other(buffer, dict, other_count)
	return dict

## 写入小字典条目（总数 ≤5）：用泛型方法写入每个值，键统一用字符串编码
static func _write_small_dict_entries(buffer: StreamPeerBuffer, dict: Dictionary[StringName, Variant]) -> void:
	for key: StringName in dict:
		_write_string(buffer, String(key))
		generic_write(buffer, dict[key])

## 读取小字典条目（总数 ≤5）：用泛型方法读取每个值，键还原为 StringName
static func _read_small_dict_entries(buffer: StreamPeerBuffer, count: int) -> Dictionary[StringName, Variant]:
	var dict: Dictionary[StringName, Variant] = {}
	for _i in range(count):
		var key: StringName = StringName(_read_string(buffer))
		var val: Variant = generic_read(buffer)
		dict[key] = val
	return dict

## 将字典条目按值类型分为五组：[int, float, string, bool, other]
static func _classify_dict_entries(dict: Dictionary[StringName, Variant]) -> Array[Dictionary]:
	var groups: Array[Dictionary] = [{}, {}, {}, {}, {}]
	for key: StringName in dict:
		var val: Variant = dict[key]
		match typeof(val):
			TYPE_INT:
				groups[0][key] = val
			TYPE_FLOAT:
				groups[1][key] = val
			TYPE_STRING:
				groups[2][key] = val
			TYPE_BOOL:
				groups[3][key] = val
			_:
				groups[4][key] = val
	return groups

## 写入 int 组：数量头 + 键 + zigzag varint 值
static func _write_group_int(buffer: StreamPeerBuffer, group: Dictionary[StringName, Variant]) -> void:
	_write_varint(buffer, group.size())
	for key: StringName in group:
		_write_string(buffer, String(key))
		_write_varint(buffer, group[key])

## 写入 float 组：数量头 + 键 + double
static func _write_group_float(buffer: StreamPeerBuffer, group: Dictionary[StringName, Variant]) -> void:
	_write_varint(buffer, group.size())
	for key: StringName in group:
		_write_string(buffer, String(key))
		buffer.put_double(group[key])

## 写入 string 组：数量头 + 键 + 字符串
static func _write_group_string(buffer: StreamPeerBuffer, group: Dictionary[StringName, Variant]) -> void:
	_write_varint(buffer, group.size())
	for key: StringName in group:
		_write_string(buffer, String(key))
		_write_string(buffer, group[key])

## 写入 bool 组：数量头 + 键 + 单字节
static func _write_group_bool(buffer: StreamPeerBuffer, group: Dictionary[StringName, Variant]) -> void:
	_write_varint(buffer, group.size())
	for key: StringName in group:
		_write_string(buffer, String(key))
		_write_bool(buffer, group[key])

## 写入 other 组（无数量头）：键用字符串编码，值用泛型方法自描述写入
static func _write_group_other(buffer: StreamPeerBuffer, group: Dictionary[StringName, Variant]) -> void:
	for key: StringName in group:
		_write_string(buffer, String(key))
		generic_write(buffer, group[key])

## 读取 int 组：先读数量，循环读键和 zigzag varint 值，装配到字典，返回条目数
static func _read_group_int(buffer: StreamPeerBuffer, dict: Dictionary[StringName, Variant]) -> int:
	var count: int = _read_varint(buffer)
	for _i in range(count):
		var key: StringName = StringName(_read_string(buffer))
		var val: int = _read_varint(buffer)
		dict[key] = val
	return count

## 读取 float 组：先读数量，循环读键和 double，返回条目数
static func _read_group_float(buffer: StreamPeerBuffer, dict: Dictionary[StringName, Variant]) -> int:
	var count: int = _read_varint(buffer)
	for _i in range(count):
		var key: StringName = StringName(_read_string(buffer))
		var val: float = buffer.get_double()
		dict[key] = val
	return count

## 读取 string 组：先读数量，循环读键和字符串，返回条目数
static func _read_group_string(buffer: StreamPeerBuffer, dict: Dictionary[StringName, Variant]) -> int:
	var count: int = _read_varint(buffer)
	for _i in range(count):
		var key: StringName = StringName(_read_string(buffer))
		var val: String = _read_string(buffer)
		dict[key] = val
	return count

## 读取 bool 组：先读数量，循环读键和单字节，返回条目数
static func _read_group_bool(buffer: StreamPeerBuffer, dict: Dictionary[StringName, Variant]) -> int:
	var count: int = _read_varint(buffer)
	for _i in range(count):
		var key: StringName = StringName(_read_string(buffer))
		var val: bool = _read_bool(buffer)
		dict[key] = val
	return count

## 读取 other 组：按给定数量循环读键，值用泛型方法自描述恢复
static func _read_group_other(buffer: StreamPeerBuffer, dict: Dictionary[StringName, Variant], count: int) -> void:
	for _i in range(count):
		var key: StringName = StringName(_read_string(buffer))
		var val: Variant = generic_read(buffer)
		dict[key] = val
