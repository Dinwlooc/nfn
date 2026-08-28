## NPC 对等端管理器，负责为 AI 玩家创建和管理 NPC 决策请求。
extends RefCounted
class_name NPCPeerManager

#=== Constants ===
const MAX_RETRIES: int = 5

#=== Variables ===
var _game_state: GameState
var _npc_peers: Dictionary[int, NPCPeer] = {}
var _retry_counts: Dictionary[int, int] = {}
var _decision_serial: Dictionary[int, int] = {}   # 决策序列号，用于忽略过期回调

#=== Signals ===
## 操作请求信号（期望监听者处理）
## @requester
signal operation_requested(request: OperationRequest)

#=== Constructor ===
## 构造函数
## @endo
func _init(game_state: GameState) -> void:
	_game_state = game_state
	_game_state.player_manager.player_added.connect(_on_player_added)

#=== Public Methods ===
## 当权限更新时，尝试为相关玩家发送 NPC 请求
## @endo
func on_permissions_updated(player_ids: PackedInt32Array) -> void:
	for player_id in player_ids:
		_try_send_npc_request(player_id)
## 清理所有 NPC 对等端
## @endo
func clear() -> void:
	for npc in _npc_peers.values():
		npc.cleanup()
	_npc_peers.clear()
	_retry_counts.clear()
	_decision_serial.clear()
## 发射操作请求信号（供外部监听）
## @emitter
func emit_operation_requested(request: OperationRequest) -> void:
	operation_requested.emit(request)

#=== Private Methods ===
## 玩家添加回调（仅当为 AI 玩家时创建 NPC 对等端）
## @endo
func _on_player_added(player: Player) -> void:
	if player.peer_id != PlayersManager.ai_peer_id:
		return
	var player_id = player.get_id()
	if _npc_peers.has(player_id):
		return
	var npc = AutoNPCPeer.new(_game_state, player_id)
	_npc_peers[player_id] = npc
## 请求取消时的重试逻辑
## @endo
func _on_request_cancelled(player_id: int) -> void:
	var count = _retry_counts.get(player_id, 0)
	if count < MAX_RETRIES:
		_retry_counts[player_id] = count + 1
		call_deferred(&"_retry_request", player_id)
	else:
		var abandon_req := OperationRequest.AbandonResponse.new(player_id).use_npc_peer_id()
		_retry_counts.erase(player_id)
		call_deferred(&"emit_operation_requested", abandon_req)
## 重试请求
## @endo
func _retry_request(player_id: int) -> void:
	if not _npc_peers.has(player_id):
		return
	var npc = _npc_peers[player_id]
	_request_decision_async(player_id, npc)
## 尝试发送 NPC 请求（等待 NPC 就绪）
## @endo
func _try_send_npc_request(player_id: int) -> void:
	if not _npc_peers.has(player_id):
		return
	var npc = _npc_peers[player_id]
	await npc.await_npc_ready()
	_retry_counts.erase(player_id)
	_request_decision_async(player_id, npc)
## 异步请求决策
## @endo
func _request_decision_async(player_id: int, npc: NPCPeer) -> void:
	var serial = _decision_serial.get(player_id, 0) + 1
	_decision_serial[player_id] = serial
	npc.request_decision_async(func(request: OperationRequest):
		_on_npc_decision(player_id, serial, request)
	)
## NPC 决策回调
## @endo
func _on_npc_decision(player_id: int, serial: int, request: OperationRequest) -> void:
	if _decision_serial.get(player_id) != serial:
		return
	_decision_serial.erase(player_id)
	if request == null:
		request = OperationRequest.AbandonResponse.new(player_id).use_npc_peer_id()
	request.cancelled.connect(_on_request_cancelled.bind(player_id), CONNECT_ONE_SHOT)
	emit_operation_requested(request)
