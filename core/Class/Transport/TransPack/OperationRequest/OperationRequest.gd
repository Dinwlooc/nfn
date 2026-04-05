extends TransPack
class_name OperationRequest

enum State{ PROCESS,CANCELLED,COMPLETED }

var source_peer_id:int
var source_player_id:int
var state:State = State.PROCESS
signal cancelled()
signal completed()
static func get_class_name_static() -> StringName:
	return &"base_request"
func use_npc_peer_id() -> OperationRequest:
	source_peer_id = -1
	return self
func cancel() -> void:
	state = State.CANCELLED
	cancelled.emit()
func complete() -> void:
	state = State.COMPLETED
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
	func _init(player_id:int = -1,card_id:int = -1,target_id:int =-1) -> void:
		source_player_id = player_id
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
			pack = PlayCard.new()
		super.deserialize_from_buffer(buffer,pack)
		pack ._card_id = TransPackSerializer.read(buffer, TYPE_INT)
		pack ._target_id = TransPackSerializer.read(buffer, TYPE_INT)
		return pack
## 放弃响应操作请求，通常产生与响应超时相同的效果。
class AbandonResponse extends OperationRequest:
	static func get_class_name_static() -> StringName:
		return &"abandon_response"
	func _init(player_id:int = -1) -> void:
		source_player_id = player_id
	static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = NULL_PACK) -> OperationRequest:
		if pack == NULL_PACK:
			pack = AbandonResponse.new()
		super.deserialize_from_buffer(buffer,pack)
		return pack

class DiscardCards extends OperationRequest:
	var _card_ids: PackedInt32Array

	func _init(player_id: int = -1, card_ids: PackedInt32Array = PackedInt32Array()) -> void:
		source_player_id = player_id
		_card_ids = card_ids

	static func get_class_name_static() -> StringName:
		return &"discard_cards"

	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		super.serialize_to_buffer(buffer)
		TransPackSerializer.write(buffer, _card_ids.size())
		for id in _card_ids:
			TransPackSerializer.write(buffer, id)

	static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = NULL_PACK) -> OperationRequest:
		if pack == NULL_PACK:
			pack = DiscardCards.new()
		super.deserialize_from_buffer(buffer, pack)
		var size: int = TransPackSerializer.read(buffer, TYPE_INT)
		var ids: PackedInt32Array = []
		for i in size:
			ids.append(TransPackSerializer.read(buffer, TYPE_INT))
		pack._card_ids = ids
		return pack
