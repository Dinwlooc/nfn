extends TransPack
class_name OperationRequest

var source_peer_id:int
var source_player_id:int
signal cancelled()
signal completed()
static func get_class_name_static() -> StringName:
	return &"base_request"  # 虚方法
func cancel() -> void:
	cancelled.emit()
func complete() -> void:
	completed.emit()
func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	pass
static func deserialize_from_buffer(buffer: StreamPeerBuffer,pack:TransPack = NULL_PACK) -> OperationRequest:
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
		TransPackSerializer.write(buffer, _card_id)
		TransPackSerializer.write(buffer, _target_id)
	static func deserialize_from_buffer(buffer: StreamPeerBuffer,pack:TransPack = NULL_PACK) -> OperationRequest:
		var instance = PlayCard.new(0,0)
		instance._card_id = TransPackSerializer.read(buffer, TYPE_INT)
		instance._target_id = TransPackSerializer.read(buffer, TYPE_INT)
		return instance
## 放弃响应操作请求，通常产生与响应超时相同的效果。
class AbandonResponse extends OperationRequest:
	static func get_class_name_static() -> StringName:
		return &"abandon_response"
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		pass
	static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = NULL_PACK) -> OperationRequest:
		return AbandonResponse.new()
