extends TransPack
class_name OperationRequest

var source_peer_id:int
var source_player_id:int

func send()->void:
	GlobalTransport.upload_operation_request(self)
func create_behavior_command()->BehaviorCommand:
	return null

class PlayCard extends OperationRequest:
	var card_id: int
	var target_id: int
	var is_to_center:bool
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		TransPackSerializer.write(buffer, card_id)
		TransPackSerializer.write(buffer, target_id)
	static func deserialize_from_buffer(buffer: StreamPeerBuffer) -> OperationRequest:
		var instance = PlayCard.new()
		instance.card_id = TransPackSerializer.read(buffer, TYPE_INT)
		instance.target_id = TransPackSerializer.read(buffer, TYPE_INT)
		return instance
	func create_behavior_command()->BehaviorCommand:
		var card:PackedInt32Array = [card_id]
		var mode:PlayCardsCommand.TargetAreaType = PlayCardsCommand.TargetAreaType.PLAYER_DEF
		if is_to_center:
			mode = PlayCardsCommand.TargetAreaType.CENTER
		return PlayCardsCommand.new(source_player_id,card,target_id,mode)
