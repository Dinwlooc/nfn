extends BaseSerializer
class_name OperationRequestSerializer
enum Type {
	PLAY_CARDS,
	END
}
const PlayCard = OperationRequest.PlayCard
# 序列化OperationEvent及其子类
static func serialize(obj: OperationRequest) -> PackedByteArray:
	var buffer = StreamPeerBuffer.new()
	BaseSerializer.write(buffer, obj.type)
	if obj is OperationRequest.PlayCard:
		var play_card: OperationRequest.PlayCard = obj
		BaseSerializer.write(buffer, play_card.card_id)
		BaseSerializer.write(buffer, play_card.target_id)
	return buffer.data_array

# 反序列化并重建对象
static func deserialize(serialized_data: PackedByteArray) -> OperationRequest:
	var buffer = StreamPeerBuffer.new()
	buffer.put_data(serialized_data)
	buffer.seek(0)
	var obj_type = BaseSerializer.read(buffer, TYPE_INT)
	match obj_type:
		Type.PLAY_CARDS:
			var play_card = OperationRequest.PlayCard.new()
			play_card.card_id = BaseSerializer.read(buffer, TYPE_INT)
			play_card.target_id = BaseSerializer.read(buffer, TYPE_INT)
			return play_card
	printerr("Unknown operation type: ", obj_type)
	return null
