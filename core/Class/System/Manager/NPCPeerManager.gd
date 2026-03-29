extends RefCounted
class_name NPCPeerManager

const MAX_RETRIES: int = 5

var _game_state: GameState
var _npc_peers: Dictionary[int, NPCPeer] = {}   ## player_id -> NPCPeer
var _retry_counts: Dictionary[int, int] = {}    ## player_id -> 当前重试次数

signal operation_requested(request: OperationRequest)

## 初始化，传入游戏状态
func _init(game_state: GameState) -> void:
	_game_state = game_state
	_game_state.player_manager.player_added.connect(_on_player_added)

## 当新玩家加入时，若为 AI 玩家（peer_id == -1），则创建对应的 NPC 实例
func _on_player_added(player: Player) -> void:
	if player.peer_id != PlayersManager.ai_peer_id:
		return
	var player_id := player.player_id
	if _npc_peers.has(player_id):
		return
	var npc := AutoNPCPeer.new(_game_state, player_id)
	_npc_peers[player_id] = npc

## 供外部调用，当某些玩家的响应权限发生变化时，触发这些玩家尝试生成操作请求。
## 传入 player_ids 数组，遍历每个玩家，若存在 NPC 实例则调用其 get_operation_request() 获取请求。
func on_permissions_updated(player_ids: PackedInt32Array) -> void:
	for player_id in player_ids:
		_try_send_npc_request(player_id)

## 当某个操作请求被取消时，根据重试次数决定是否重试或放弃
func _on_request_cancelled(player_id: int) -> void:
	var count: int = _retry_counts.get(player_id, 0)
	if count < MAX_RETRIES:
		_retry_counts[player_id] = count + 1
		call_deferred(&"_retry_request",player_id)
	else:
		var abandon_req := OperationRequest.AbandonResponse.new(player_id).use_npc_peer_id()
		_retry_counts.erase(player_id)
		operation_requested.emit(abandon_req)

## 延迟重试：重新调用该玩家的 get_operation_request() 并发射
func _retry_request(player_id: int) -> void:
	if not _npc_peers.has(player_id):
		return
	var npc := _npc_peers[player_id]
	var request :OperationRequest = await npc.get_operation_request()
	if request == null:
		return
	request.cancelled.connect(_on_request_cancelled.bind(request.source_player_id))
	operation_requested.emit(request)

## 尝试发送NPC请求：重置重试计数，然后调用重试逻辑
func _try_send_npc_request(player_id: int) -> void:
	if not _npc_peers.has(player_id):
		return
	var npc := _npc_peers[player_id]
	await npc.await_npc_ready()
	# 重置该玩家的重试计数（新的一轮激活）
	_retry_counts.erase(player_id)
	_retry_request(player_id)

## 可选：清理所有 NPC（例如游戏结束时）
func clear() -> void:
	for npc in _npc_peers.values():
		npc.cleanup()
	_npc_peers.clear()
	_retry_counts.clear()
