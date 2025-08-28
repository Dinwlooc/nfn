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
	# 添加其他事件类型...
}

enum PlayCardsKeys {
	CARD_IDS = BaseKeys.END,
	TARGET_IDS,
	END
}

const PlayCards = OperationRequest.PlayCards
# 序列化OperationEvent及其子类
static func serialize(obj:OperationRequest) -> PackedByteArray:
	var data = Data.new(BaseKeys.END)
	serialize_write(BaseKeys.TYPE, obj.type, data)
	if obj is PlayCards:
		data.main_data.resize(PlayCardsKeys.END)
		serialize_write(PlayCardsKeys.CARD_IDS, obj.card_ids, data)
		serialize_write(PlayCardsKeys.TARGET_IDS, obj.target_ids, data)
	return data_to_byte(data)

# 反序列化并重建对象
static func deserialize(serialized_data:PackedByteArray):
	var data_array = byte_to_data_array(serialized_data)
	var event_type = data_array[BaseKeys.TYPE]
	match event_type:
		Type.PLAY_CARDS:
			var event = PlayCards.new()
			event.card_ids = data_array[PlayCardsKeys.CARD_IDS]
			event.target_ids = data_array[PlayCardsKeys.TARGET_IDS]
			return event
		# 其他事件类型的处理...
		_:
			printerr("Unknown event type: ", event_type)
			return null
