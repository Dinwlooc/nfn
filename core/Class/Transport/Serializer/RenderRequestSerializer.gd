extends TransPackSerializer
class_name RenderRequestSerializer

# 所有支持的渲染请求类型数组（官方类型 + 模组追加）
static var render_request_classes: Array[Script] = [
	RenderRequest.ItemAdd,
	RenderRequest.ItemRemove,
	RenderRequest.ItemUpdate
]

# 构建注册表（类 -> 索引）
static var _registry: Dictionary = build_registry(render_request_classes)

# 序列化RenderRequest对象
static func serialize(obj: RenderRequest) -> PackedByteArray:
	var buffer = StreamPeerBuffer.new()
	serialize_with_registry(buffer, obj, _registry)
	return buffer.data_array

# 反序列化数据
static func deserialize(serialized_data: PackedByteArray) -> RenderRequest:
	var buffer = StreamPeerBuffer.new()
	buffer.data_array = serialized_data
	var result = deserialize_with_registry(buffer, render_request_classes)
	return result as RenderRequest
