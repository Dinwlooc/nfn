# TransPackSerializer.gd
extends RefCounted
class_name TransPackSerializer

static func write(buffer: StreamPeerBuffer, value:Variant) -> void:
	SerializationUtil.write(buffer,value)

static func read(buffer: StreamPeerBuffer, type: int)->Variant:
	return SerializationUtil.read(buffer,type)
# 构建类名到索引的映射
static func build_registry(classes: Array[Script]) -> Dictionary[StringName, int]:
	var dic:Dictionary[StringName, int] = {}
	for idx in classes.size():
		var _class_name = classes[idx].get_class_name_static()
		dic[_class_name] = idx
	return dic

# 使用类名进行序列化
static func serialize_with_registry(
	buffer: StreamPeerBuffer,
	obj: TransPack,
	registry: Dictionary[StringName, int]
) -> void:
	var _class_name = obj.get_class_name()
	var class_idx = registry.get(_class_name, -1)
	if class_idx == -1:
		push_error("Unknown class in registry: " + _class_name)
		write(buffer, -1)  # 无效标识
	else:
		write(buffer, class_idx)
		obj.serialize_to_buffer(buffer)

# 泛型对象反序列化方法（使用反向注册表）
static func deserialize_with_registry(buffer: StreamPeerBuffer, reverse_registry: Array[Script]) -> Object:
	var class_idx = read(buffer, TYPE_INT)
	var obj_class = reverse_registry[class_idx]
	return obj_class.deserialize_from_buffer(buffer)
