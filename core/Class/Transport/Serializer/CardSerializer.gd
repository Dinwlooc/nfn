extends BaseSerializer
class_name CardSerializer

enum CardClass {
	CARD_PACK ,
	HAND_CARD_PACK,
	MODE_CARD_PACK
}

const VERSION = 1

# 序列化传输包
static func serialize(pack: TransPack) -> PackedByteArray:
	var buffer = StreamPeerBuffer.new()
	write(buffer, VERSION)
	if pack is HandCardPack:
		write(buffer, CardClass.HAND_CARD_PACK)
	elif pack is CardPack:
		write(buffer, CardClass.CARD_PACK)
	else:
		write(buffer, CardClass.MODE_CARD_PACK)
		write(buffer,pack.get_class())
	pack.serialize_to_buffer(buffer)
	return buffer.data_array

# 反序列化传输包
static func deserialize(data: PackedByteArray) -> CardPack:
	var buffer = StreamPeerBuffer.new()
	buffer.data_array = data
	var version = read(buffer, TYPE_INT)
	if version != VERSION:
		push_error("Version mismatch. Expected: " + str(VERSION) + ", Got: " + str(version))
		return null
	var class_type = read(buffer, TYPE_INT)
	match class_type:
		CardClass.CARD_PACK:
			return CardPack.deserialize_from_buffer(buffer)
		CardClass.HAND_CARD_PACK:
			return HandCardPack.deserialize_from_buffer(buffer)
		CardClass.MODE_CARD_PACK:
			var mod_class:StringName = read(buffer, TYPE_STRING_NAME)
			return ClassDB.class_call_static(mod_class,&"deserialize_from_buffer")
		_:
			push_error("Unknown card class type: " + str(class_type))
			return null

# 序列化传输包数组
static func serialize_array(packs: Array[CardPack]) -> PackedByteArray:
	var buffer = StreamPeerBuffer.new()
	write(buffer, packs.size())
	for pack in packs:
		var pack_data:PackedByteArray = serialize(pack)
		write(buffer, pack_data.size())
		buffer.put_data(pack_data)
	return buffer.data_array

# 反序列化传输包数组
static func deserialize_array(data: PackedByteArray) -> Array[CardPack]:
	var buffer = StreamPeerBuffer.new()
	buffer.data_array = data
	var result: Array[CardPack] = []
	var array_size = read(buffer, TYPE_INT)
	for _i in range(array_size):
		var pack_size = read(buffer, TYPE_INT)
		var pack_data = buffer.get_data(pack_size)
		if pack_data[0] != OK:
			push_error("Failed to read pack data")
			continue
		var pack:CardPack = deserialize(pack_data[1])
		if pack:
			result.append(pack)
	return result
