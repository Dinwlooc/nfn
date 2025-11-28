extends RefCounted
class_name OperationHandler

var player_permissions: Dictionary[int,Array] = {}
var responded_players: Dictionary[int,bool] = {}
var _peer_player_map :Dictionary[int,int] = {}
signal operation_validated(request: OperationRequest)  # 修改信号：发射操作请求而非行为命令
signal permissions_updated

func reset_response_locks() -> void:
	responded_players.clear()

func update_permissions_map(permissions_map:Dictionary[int,Array]) ->void:
	player_permissions = permissions_map

func set_player_permissions(player_id: int, permissions: Array[StringName]) -> void:
	player_permissions[player_id] = permissions
	permissions_updated.emit()

func apply_player_blacklist(player_id: int, blacklist: Array[StringName]) -> void:
	if not player_permissions.has(player_id):
		return
	var ops = player_permissions[player_id]
	var i = 0
	while i < ops.size():
		if blacklist.has(ops[i]):
			ops.remove_at(i)
		else:
			i += 1
	if ops.is_empty():
		player_permissions.erase(player_id)
	permissions_updated.emit()
	
func update_verification_mapping(peer_id: int, player_id: int) -> void:
	_peer_player_map[peer_id] = player_id
	
func verify_operation(request: OperationRequest) -> bool:
	var source_player_id = _peer_player_map.get(request.source_peer_id, -1)
	return source_player_id == request.source_player_id

func handle_request(request: OperationRequest) -> void:
	if !verify_operation(request):
		return
	var player_id = request.source_player_id
	if responded_players.has(player_id):
		return
	var allowed_ops = player_permissions.get(player_id, [])
	var request_type = request.get_class_name()
	if allowed_ops.has(request_type):
		operation_validated.emit(request)  # 发送验证后的操作请求
		responded_players[player_id] = true
