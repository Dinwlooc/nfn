extends TransPack
class_name RenderRequest

var target_area: StringName
func send_to_player(peer_id: int) -> void:
	if peer_id != -1:
		GlobalTransport.send_render_request(peer_id, self)
	else:
		return

class ItemAdd extends  RenderRequest:
	var item_data: Array[TransPack]
	func _init(area: StringName, data: Array[TransPack]):
		target_area = area
		item_data = data

class CardAdd extends RenderRequest:
	var card_data: Array[CardPack]
	func _init(area: StringName, data: Array[CardPack]):
		target_area = area
		card_data = data
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		SerializationUtil.write(buffer, target_area)
		CardPackSerializer.serialize_array(card_data,buffer)
	static func deserialize_from_buffer(buffer: StreamPeerBuffer) -> RenderRequest:
		var area:StringName = SerializationUtil.read(buffer, TYPE_STRING_NAME)
		var cards:Array[TransPack] = CardPackSerializer.deserialize_array(buffer)
		return ItemAdd.new(area, cards)
# 移除卡牌请求
class CardRemove extends RenderRequest:
	var uids_data: PackedInt32Array
	func _init(area: StringName, data: PackedInt32Array):
		target_area = area
		uids_data = data
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		SerializationUtil.write(buffer, target_area)
		SerializationUtil.write(buffer, uids_data)
	static func deserialize_from_buffer(buffer: StreamPeerBuffer) -> RenderRequest:
		var area:StringName = SerializationUtil.read(buffer, TYPE_STRING_NAME) as StringName
		var uids:PackedInt32Array = SerializationUtil.read(buffer, TYPE_PACKED_INT32_ARRAY)
		return CardRemove.new(area, uids)
		
class PlayerUpdate extends RenderRequest:
	var player_pack: PlayerPack
	func _init(area: StringName, pack: PlayerPack):
		target_area = area
		player_pack = pack
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		SerializationUtil.write(buffer, target_area)
		player_pack.serialize_to_buffer(buffer)
	static func deserialize_from_buffer(buffer: StreamPeerBuffer) -> RenderRequest:
		var area: StringName = SerializationUtil.read(buffer, TYPE_STRING_NAME) as StringName
		var pack: PlayerPack = PlayerPack.deserialize_from_buffer(buffer)
		return PlayerUpdate.new(area, pack)
