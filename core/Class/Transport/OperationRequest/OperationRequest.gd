extends TransPack
class_name OperationRequest

var source_peer_id:int
var source_player_id:int

func send()->void:
	GlobalTransport.upload_operation_request(self)
func create_behavior_command()->BehaviorCommand:
	return null

class PlayCard extends OperationRequest:
	var _card_id: int
	var _target_id: int
	var _is_to_center:bool
	func _init(card_id,target_id) -> void:
		_card_id = card_id
		_target_id = target_id
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		TransPackSerializer.write(buffer, _card_id)
		TransPackSerializer.write(buffer, _target_id)
	static func deserialize_from_buffer(buffer: StreamPeerBuffer) -> OperationRequest:
		var instance = PlayCard.new(0,0)
		instance._card_id = TransPackSerializer.read(buffer, TYPE_INT)
		instance._target_id = TransPackSerializer.read(buffer, TYPE_INT)
		return instance
	func create_behavior_command()->BehaviorCommand:
		var card:PackedInt32Array = [_card_id]
		var mode:PlayCardsCommand.TargetAreaType = PlayCardsCommand.TargetAreaType.PLAYER_DEF
		if _is_to_center:
			mode = PlayCardsCommand.TargetAreaType.CENTER
		return PlayCardsCommand.new(source_player_id,card,_target_id,mode)
