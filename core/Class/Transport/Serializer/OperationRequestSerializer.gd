extends TransPackSerializer
class_name OperationRequestSerializer

# 所有支持的操作请求类型数组
static var operation_classes: Array[Script] = [
	OperationRequest.PlayCard,
	OperationRequest.AbandonResponse,
	OperationRequest.DiscardCards
]

# 构建双向注册表
static var _registry:  Dictionary[StringName,int] = build_registry(operation_classes)

# 序列化OperationRequest
static func serialize(obj: OperationRequest) -> PackedByteArray:
	var buffer = StreamPeerBuffer.new()
	serialize_with_registry(buffer, obj, _registry)
	return buffer.data_array

# 反序列化OperationRequest
static func deserialize(serialized_data: PackedByteArray) -> OperationRequest:
	var buffer = StreamPeerBuffer.new()
	buffer.data_array = serialized_data
	var result = deserialize_with_registry(buffer,operation_classes)
	return result as OperationRequest
