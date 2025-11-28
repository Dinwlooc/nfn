extends TransPack
class_name OperationRequest

var source_peer_id:int
var source_player_id:int
static func get_class_name_static() -> StringName:
	return &"base_request"  # 虚方法
func create_behavior_command()->BehaviorCommand:
	return null

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
	static func deserialize_from_buffer(buffer: StreamPeerBuffer) -> OperationRequest:
		var instance = PlayCard.new(0,0)
		instance._card_id = TransPackSerializer.read(buffer, TYPE_INT)
		instance._target_id = TransPackSerializer.read(buffer, TYPE_INT)
		return instance
