extends RefCounted
class_name OperationRequestHandler

var players_manager:PlayersManager
signal request_validated(command: BehaviorCommand)

func handle_request(request: OperationRequest) -> void:
	if players_manager.is_operation_allowed(request.source_player_id, request.get_request_type()):
		var command = request.create_behavior_command()
		request_validated.emit(command)
