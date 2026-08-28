## 所有数据包抽象基类，定义序列化、版本管理等公共接口。
@abstract
extends RefCounted
class_name TransPack
## 版本号，用于增量更新时的顺序校验。
var version: int = 0
## 抽象序列化方法。
@abstract func serialize_to_buffer(_buffer: StreamPeerBuffer) -> void
## 反序列化静态方法。
## @heritage-override
static func deserialize_from_buffer(_buffer: StreamPeerBuffer, _pack_override: TransPack) -> TransPack:
	push_error("TransPack.deserialize_from_buffer() must be overridden in subclass")
	return null
## 获取类名字符串（静态）。
## @force-override
static func get_class_name_static() -> StringName:
	push_error("Must override get_class_name_static() in subclass")
	return &"TransPack"
## 实例方法，返回类名。
## @pure
func get_class_name() -> StringName:
	return get_class_name_static()
