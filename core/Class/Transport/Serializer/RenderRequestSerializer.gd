extends BaseSerializer
class_name RenderRequestSerializer

# 定义与RenderRequest相同的枚举类型
enum Type {
	CARD_ADD,
	CARD_REMOVE
}

# 序列化RenderRequest及其子类
static func serialize(obj: RenderRequest) -> PackedByteArray:
	var buffer = StreamPeerBuffer.new()
	write(buffer, obj.request_type)
	if obj is RenderRequest.CardADD:
		var card_add: RenderRequest.CardADD = obj
		write(buffer, card_add.target_area)
		write(buffer, CardSerializer.serialize_array(card_add.card_data))
	elif obj is RenderRequest.CardRemove:
		var card_remove: RenderRequest.CardRemove = obj
		write(buffer, card_remove.target_area)
		write(buffer, card_remove.uids_data)
	else:
		printerr("Unsupported render request type: ", obj.request_type)
	return buffer.data_array

# 反序列化并重建对象
static func deserialize(serialized_data: PackedByteArray) -> RenderRequest:
	var buffer = StreamPeerBuffer.new()
	buffer.put_data(serialized_data)
	buffer.seek(0)
	var request_type = read(buffer, TYPE_INT)
	match request_type:
		RenderRequest.REQUEST_TYPE.CARD_ADD:
			var target_area = read(buffer, TYPE_STRING_NAME) as StringName
			var card_data = CardSerializer.deserialize_array(BaseSerializer.read(buffer, TYPE_PACKED_BYTE_ARRAY))
			var card_add = RenderRequest.CardADD.new(target_area,card_data)
			return card_add
		RenderRequest.REQUEST_TYPE.CARD_REMOVE:
			var target_area = read(buffer, TYPE_STRING_NAME) as StringName
			var uids_data = read(buffer, TYPE_PACKED_INT32_ARRAY)
			var card_remove = RenderRequest.CardRemove.new(target_area, uids_data)
			return card_remove     
		_:
			printerr("Unknown render request type: ", request_type)
			return null
