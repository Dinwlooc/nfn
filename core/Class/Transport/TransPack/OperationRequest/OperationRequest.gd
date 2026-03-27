extends TransPack
class_name OperationRequest

var source_peer_id:int
var source_player_id:int
signal cancelled()
signal completed()
static func get_class_name_static() -> StringName:
	return &"base_request"
func use_npc_peer_id() -> OperationRequest:
	source_peer_id = -1
	return self
func cancel() -> void:
	cancelled.emit()
func complete() -> void:
	completed.emit()
func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	TransPackSerializer.write(buffer, source_player_id)
static func deserialize_from_buffer(buffer: StreamPeerBuffer,pack:TransPack = NULL_PACK) -> OperationRequest:
	if pack == NULL_PACK:
		pack = OperationRequest.new()
	pack.source_player_id = TransPackSerializer.read(buffer, TYPE_INT)
	return OperationRequest.new()

class PlayCard extends OperationRequest:
	var _card_id: int
	var _target_id: int
	var _is_to_center:bool
	func _init(card_id,target_id) -> void:
		_card_id = card_id
		_target_id = target_id
	static func get_class_name_static() -> StringName:
		return &"play_card"
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		super.serialize_to_buffer(buffer)
		TransPackSerializer.write(buffer, _card_id)
		TransPackSerializer.write(buffer, _target_id)
	static func deserialize_from_buffer(buffer: StreamPeerBuffer,pack:TransPack = NULL_PACK) -> OperationRequest:
		if pack == NULL_PACK:
			pack = PlayCard.new(0,0)
		super.deserialize_from_buffer(buffer,pack)
		pack ._card_id = TransPackSerializer.read(buffer, TYPE_INT)
		pack ._target_id = TransPackSerializer.read(buffer, TYPE_INT)
		return pack
## 放弃响应操作请求，通常产生与响应超时相同的效果。
class AbandonResponse extends OperationRequest:
	static func get_class_name_static() -> StringName:
		return &"abandon_response"
	func _init(player_id:int) -> void:
		source_player_id = player_id
	static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = NULL_PACK) -> OperationRequest:
		if pack == NULL_PACK:
			pack = AbandonResponse.new(0)
		super.deserialize_from_buffer(buffer,pack)
		return pack
