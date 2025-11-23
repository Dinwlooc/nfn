extends TransPackSerializer
class_name CardPackSerializer

static var card_classes: Array[Script] = [
	CardPack,
	HandCardPack]
static var _registry: Dictionary[Script,int] = build_registry(card_classes)
# 序列化传输包
static func serialize(pack: CardPack,buffer = StreamPeerBuffer.new()) -> PackedByteArray:
	serialize_with_registry(buffer, pack, _registry)
	return buffer.data_array

# 反序列化传输包
static func deserialize(buffer:StreamPeerBuffer) -> CardPack:
	var result = deserialize_with_registry(buffer, card_classes)
	return result as CardPack
# 序列化传输包数组
static func serialize_array(packs: Array[CardPack],buffer :StreamPeerBuffer= StreamPeerBuffer.new()) -> PackedByteArray:
	write(buffer,packs.size())  # 写入数组大小
	for pack in packs:
		serialize_with_registry(buffer, pack, _registry)
	return buffer.data_array
# 优化的反序列化数组方法（无需长度字段）
static func deserialize_array(buffer :StreamPeerBuffer) -> Array[TransPack]:
	var result: Array[TransPack] = []
	var array_size:int = read(buffer,TYPE_INT)  # 读取数组大小
	result.resize(array_size)
	for i in range(array_size):
		var pack = deserialize_with_registry(buffer, card_classes)
		result.set(i,pack)
	return result
