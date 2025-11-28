extends TransPackSerializer
class_name ItemSerializer

static var item_classes: Array[Script] = [
	CardPack,
	HandCardPack,
	PlayerPack
]
static var _registry: Dictionary[StringName,int] = build_registry(item_classes)

# 序列化单个Item
static func serialize(item: TransPack, buffer = StreamPeerBuffer.new()) -> PackedByteArray:
	serialize_with_registry(buffer, item, _registry)
	return buffer.data_array
# 反序列化单个Item
static func deserialize(buffer: StreamPeerBuffer) -> TransPack:
	var result = deserialize_with_registry(buffer, item_classes)
	return result as TransPack
# 序列化Item数组
static func serialize_array(items: Array, buffer: StreamPeerBuffer = StreamPeerBuffer.new()) -> PackedByteArray:
	write(buffer, items.size())
	for item in items:
		serialize_with_registry(buffer, item, _registry)
	return buffer.data_array
# 反序列化Item数组
static func deserialize_array(buffer: StreamPeerBuffer) -> Array[TransPack]:
	var result: Array[TransPack] = []
	var array_size: int = read(buffer, TYPE_INT)
	result.resize(array_size)
	for i in range(array_size):
		result[i] = deserialize_with_registry(buffer, item_classes)
	return result
