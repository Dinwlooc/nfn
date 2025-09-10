extends BaseSerializer
class_name RenderRequestSerializer

# 内部枚举类型定义
enum Type {
	CARD_ADD,
	CARD_REMOVE,
	MOD_REQUEST  # 模组请求支持
}

# 序列化RenderRequest对象
static func serialize(obj: RenderRequest) -> PackedByteArray:
	var buffer = StreamPeerBuffer.new()
	if obj is RenderRequest.CardAdd:
		write(buffer, Type.CARD_ADD)
	elif obj is RenderRequest.CardRemove:
		write(buffer, Type.CARD_REMOVE)
	else:  # 模组请求处理
		write(buffer, Type.MOD_REQUEST)
		write(buffer, obj.get_class())  # 写入类名
	obj.serialize_to_buffer(buffer)
	return buffer.data_array

# 反序列化数据
static func deserialize(serialized_data: PackedByteArray) -> RenderRequest:
	var buffer = StreamPeerBuffer.new()
	buffer.data_array = serialized_data
	buffer.seek(0)
	var request_type = read(buffer, TYPE_INT)
	match request_type:
		Type.CARD_ADD:
			return RenderRequest.CardAdd.deserialize_from_buffer(buffer)
		Type.CARD_REMOVE:
			return RenderRequest.CardRemove.deserialize_from_buffer(buffer)
		Type.MOD_REQUEST:
			var mod_class = read(buffer, TYPE_STRING_NAME) as StringName
			if ClassDB.class_has_method(mod_class, "deserialize_from_buffer"):
				return ClassDB.class_call_static(mod_class, "deserialize_from_buffer", [buffer])
			else:
				push_error("Mod request class %s missing deserialize method" % mod_class)
				return null
		_:
			push_error("Unknown request type: " + str(request_type))
			return null
