extends RefCounted
class_name OperationRequestHandler

var player_permissions: Dictionary[int,Array] = {}  # 更明确的变量名
var responded_players: Dictionary[int,bool] = {}
var _peer_player_map :Dictionary[int,int] = {}
signal request_validated(command: BehaviorCommand)
signal permissions_updated
# 重置处理器状态
func reset_state() -> void:
	player_permissions.clear()
	responded_players.clear()
# 设置初始权限（白名单注入）
func set_player_permissions(player_id: int, permissions: Array[StringName]) -> void:
	player_permissions[player_id] = permissions
	permissions_updated.emit()
# 应用玩家黑名单修正
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
	var request_type = request.get_request_type()
	if allowed_ops.has(request_type):
		var command = request.create_behavior_command()
		if command != null:
			request_validated.emit(command)
			responded_players[player_id] = true
