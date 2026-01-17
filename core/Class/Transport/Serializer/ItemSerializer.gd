extends TransPackSerializer
class_name ItemSerializer

static var item_classes: Array[Script] = [
	CardPack,
	HandCardPack,
	PlayerPack
]
static var _registry: Dictionary[StringName,int] = build_registry(item_classes)
static var _reverse_registry: Array[Script] = item_classes

# 序列化单个Item - 保持原接口
static func serialize(item: TransPack, buffer = StreamPeerBuffer.new()) -> PackedByteArray:
	serialize_with_registry(buffer, item, _registry)
	return buffer.data_array
# 反序列化单个Item - 保持原接口
static func deserialize(buffer: StreamPeerBuffer) -> TransPack:
	var result = deserialize_with_registry(buffer, _reverse_registry)
	return result as TransPack
# 序列化同类型Item数组 - 优化版
static func serialize_array(items: Array[ItemPack], buffer: StreamPeerBuffer = StreamPeerBuffer.new()) -> PackedByteArray:
	write(buffer, items.size())
	if items.size() == 0:
		return buffer.data_array
	var first_item = items[0]
	var _class_name:StringName = first_item.get_class_name()
	var class_idx:int = _registry.get(_class_name, -1)
	write(buffer, class_idx)
	for item in items:
		item.serialize_to_buffer(buffer)
	return buffer.data_array
# 反序列化同类型Item数组 - 优化版
static func deserialize_array(buffer: StreamPeerBuffer) -> Array[ItemPack]:
	var result: Array[ItemPack] = []
	var array_size: int = read(buffer, TYPE_INT)
	result.resize(array_size)
	if array_size == 0:
		return result
	var class_idx: int = read(buffer, TYPE_INT)
	if class_idx < 0 or class_idx >= _reverse_registry.size():
		push_error("Invalid class index: %d" % class_idx)
		return []
	var item_class:Script = _reverse_registry[class_idx]
	for i in range(array_size):
		result[i] = item_class.deserialize_from_buffer(buffer)
	return result
