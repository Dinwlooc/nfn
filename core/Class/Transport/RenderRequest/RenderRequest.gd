extends RefCounted
class_name RenderRequest

# 通信元数据
var request_type: int
enum REQUEST_TYPE {
	CARD_ADD , 
	CARD_REMOVE}

func serialize() -> PackedByteArray:
	return RenderRequestSerializer.serialize(self)

static func deserialize(serialized_data: PackedByteArray) -> RenderRequest:
	return RenderRequestSerializer.deserialize(serialized_data)

func send_to_player(player_id: int) -> void:
	GlobalTransport.send_render_request(player_id, self)
# 卡片操作请求
class CardOperation extends RenderRequest:
	var target_area: StringName
class CardADD extends CardOperation:
	var card_data: Array #传输前是Array[Card]，传输后是Array[CardData]
	func _init(area: StringName, data:Array):
		target_area = area
		request_type = REQUEST_TYPE.CARD_ADD
		card_data = data
class CardRemove extends CardOperation:
	var uids_data: PackedInt32Array # 序列化数据
	func _init(area: StringName, data:PackedInt32Array):
		target_area = area
		request_type = REQUEST_TYPE.CARD_REMOVE
		uids_data = data
