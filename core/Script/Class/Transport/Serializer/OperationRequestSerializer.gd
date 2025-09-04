# OperationEventSerializer.gd
extends BaseSerializer
class_name OperationRequestSerializer

# 将属性枚举移至序列化器
enum BaseKeys {
	TYPE,
	END # 扩展标识符
}
enum Type {
	PLAY_CARDS,
	END
}
enum PlayCardKeys {
	CARD_ID = BaseKeys.END,
	TARGET_ID,
	END
}
const PlayCard = OperationRequest.PlayCard
# 序列化OperationEvent及其子类
static func serialize(obj:OperationRequest) -> PackedByteArray:
	var data = Data.new(BaseKeys.END)
	serialize_write(BaseKeys.TYPE, obj.type, data)
	if obj is PlayCard:
		data.main_data.resize(PlayCardKeys.END)
		serialize_write(PlayCardKeys.CARD_ID, obj.card_id, data)
		serialize_write(PlayCardKeys.TARGET_ID, obj.target_id, data)
	return data_to_byte(data)

# 反序列化并重建对象
static func deserialize(serialized_data:PackedByteArray):
	var data_array = byte_to_data_array(serialized_data)
	var event_type = data_array[BaseKeys.TYPE]
	match event_type:
		Type.PLAY_CARDS:
			var event = PlayCard.new()
			event.card_id = data_array[PlayCardKeys.CARD_ID]
			event.target_id = data_array[PlayCardKeys.TARGET_ID]
			return event
		_:
			printerr("Unknown event type: ", event_type)
			return null
