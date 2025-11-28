extends RefCounted
class_name TransPack

## 必须被子类实现的序列化接口
func serialize_to_buffer(_buffer: StreamPeerBuffer) -> void:
	push_error("TransPack.serialize_to_buffer() must be overridden in subclass")
	assert(false)

## 必须被子类实现的反序列化接口
static func deserialize_from_buffer(_buffer: StreamPeerBuffer) -> TransPack:
	push_error("TransPack.deserialize_from_buffer() must be overridden in subclass")
	assert(false)
	return TransPack.new()
# 实例方法：获取类名字符串
func get_class_name() -> StringName:
	return self.get_class_name_static()
# 静态方法：获取类名字符串
static func get_class_name_static() -> StringName:
	push_error("Must override get_class_name_static() in subclass")
	return &"TransPack"
