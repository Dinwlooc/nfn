extends RefCounted
class_name TransPack

# 所有传输包的公共属性

# 必须被子类实现的序列化接口
func serialize_to_buffer(_buffer: StreamPeerBuffer) -> void:
	push_error("TransPack.serialize_to_buffer() must be overridden in subclass")
	assert(false)

# 必须被子类实现的反序列化接口
static func deserialize_from_buffer(_buffer: StreamPeerBuffer) -> TransPack:
	push_error("TransPack.deserialize_from_buffer() must be overridden in subclass")
	assert(false)
	return TransPack.new()
