extends RefCounted
class_name NPCPeerManager

const MAX_RETRIES: int = 5

var _game_state: GameState
var _npc_peers: Dictionary[int, NPCPeer] = {}
var _retry_counts: Dictionary[int, int] = {}
var _decision_serial: Dictionary[int, int] = {}   # 决策序列号，用于忽略过期回调

signal operation_requested(request: OperationRequest)

func _init(game_state: GameState) -> void:
	_game_state = game_state
	_game_state.player_manager.player_added.connect(_on_player_added)

func _on_player_added(player: Player) -> void:
	if player.peer_id != PlayersManager.ai_peer_id:
		return
	var player_id = player.get_id()
	if _npc_peers.has(player_id):
		return
	var npc = AutoNPCPeer.new(_game_state, player_id)
	_npc_peers[player_id] = npc

func on_permissions_updated(player_ids: PackedInt32Array) -> void:
	for player_id in player_ids:
		_try_send_npc_request(player_id)

func _on_request_cancelled(player_id: int) -> void:
	var count = _retry_counts.get(player_id, 0)
	if count < MAX_RETRIES:
		_retry_counts[player_id] = count + 1
		call_deferred(&"_retry_request", player_id)
	else:
		var abandon_req := OperationRequest.AbandonResponse.new(player_id).use_npc_peer_id()
		_retry_counts.erase(player_id)
		call_deferred(&"emit_operation_requested",abandon_req)

func _retry_request(player_id: int) -> void:
	if not _npc_peers.has(player_id):
		return
	var npc = _npc_peers[player_id]
	_request_decision_async(player_id, npc)

func _try_send_npc_request(player_id: int) -> void:
	if not _npc_peers.has(player_id):
		return
	var npc = _npc_peers[player_id]
	await npc.await_npc_ready()
	_retry_counts.erase(player_id)
	_request_decision_async(player_id, npc)

func _request_decision_async(player_id: int, npc: NPCPeer) -> void:
	var serial = _decision_serial.get(player_id, 0) + 1
	_decision_serial[player_id] = serial
	# 使用闭包捕获 player_id 和 serial，避免 bind 导致的类型错误
	npc.request_decision_async(func(request: OperationRequest):
		_on_npc_decision(player_id, serial, request)
	)

func _on_npc_decision(player_id: int, serial: int, request: OperationRequest) -> void:
	if _decision_serial.get(player_id) != serial:
		return
	_decision_serial.erase(player_id)
	if request == null:
		request = OperationRequest.AbandonResponse.new(player_id).use_npc_peer_id()
	request.cancelled.connect(_on_request_cancelled.bind(player_id),CONNECT_ONE_SHOT)
	emit_operation_requested(request)

func clear() -> void:
	for npc in _npc_peers.values():
		npc.cleanup()
	_npc_peers.clear()
	_retry_counts.clear()
	_decision_serial.clear()

func emit_operation_requested(request: OperationRequest):
	operation_requested.emit(request)
