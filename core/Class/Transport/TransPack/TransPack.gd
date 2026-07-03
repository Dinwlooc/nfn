@abstract
extends RefCounted
class_name TransPack

var version:int = 0

##序列化接口
@abstract func serialize_to_buffer(_buffer: StreamPeerBuffer) -> void

static func deserialize_from_buffer(_buffer: StreamPeerBuffer , _pack_override:TransPack) -> TransPack:
	push_error("TransPack.deserialize_from_buffer() must be overridden in subclass")
	assert(false)
	return null

# 静态方法：获取类名字符串
static func get_class_name_static() -> StringName:
	push_error("Must override get_class_name_static() in subclass")
	return &"TransPack"

## 获取类名StringName
func get_class_name() -> StringName:
	return self.get_class_name_static()
