extends BaseSerializer
class_name CardSerializer

static var card_classes: Array[GDScript] = [
	CardPack,
	HandCardPack
]
# 构建双向注册表
static var _registry: Dictionary[GDScript,int] = build_registry(card_classes)

# 序列化传输包
static func serialize(pack: CardPack,buffer = StreamPeerBuffer.new()) -> PackedByteArray:
	serialize_with_registry(buffer, pack, _registry)
	return buffer.data_array

# 反序列化传输包
static func deserialize(data: PackedByteArray,buffer:StreamPeerBuffer = null) -> CardPack:
	if !buffer:
		buffer = StreamPeerBuffer.new()
		buffer.data_array = data
	var result = deserialize_with_registry(buffer, card_classes)
	return result as CardPack

# 序列化传输包数组
static func serialize_array(packs: Array[CardPack]) -> PackedByteArray:
	var buffer = StreamPeerBuffer.new()
	write(buffer, packs.size())
	var temp_buffer = StreamPeerBuffer.new()
	for pack in packs:
		temp_buffer.clear()
		serialize(pack,temp_buffer)
		var data_size = temp_buffer.get_position()
		write(buffer, data_size)
		buffer.put_data(temp_buffer.data_array)
	return buffer.data_array

# 优化后的反序列化数组方法
static func deserialize_array(data: PackedByteArray) -> Array[CardPack]:
	var buffer = StreamPeerBuffer.new()
	buffer.data_array = data
	var result: Array[CardPack] = []
	var array_size = read(buffer, TYPE_INT)
	for _i in range(array_size):
		var pack_size = read(buffer, TYPE_INT)
		var pack = deserialize(data,buffer)
		result.append(pack)
	return result
	
