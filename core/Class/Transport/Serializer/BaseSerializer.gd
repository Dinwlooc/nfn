extends RefCounted
class_name BaseSerializer

static func write(buffer: StreamPeerBuffer, value) -> void:
	SerializationUtil.write(buffer,value)
	
static func read(buffer: StreamPeerBuffer, type: int)->Variant:
	return SerializationUtil.read(buffer,type)

static func build_registry(classes: Array[GDScript]) -> Dictionary[GDScript,int]:
	var dic:Dictionary[GDScript,int] = {}
	for idx in classes.size():
		dic[classes[idx]] = idx
	return dic
# 获取索引到类对象的反向注册表

static func serialize_with_registry(buffer: StreamPeerBuffer, obj:Object, registry: Dictionary[GDScript,int]) -> void:
	var class_idx = registry.get(obj.get_script())
	write(buffer, class_idx)
	obj.serialize_to_buffer(buffer)

# 泛型对象反序列化方法（使用反向注册表）
static func deserialize_with_registry(buffer: StreamPeerBuffer, reverse_registry: Array[GDScript]) -> Object:
	var class_idx = read(buffer, TYPE_INT)
	var obj_class = reverse_registry[class_idx]
	return obj_class.deserialize_from_buffer(buffer)
