## NPC 管理器（系统层桥接）：为 AI 玩家构造系统层决策快照，调度 [Agent] 决策并转发操作请求。
extends RefCounted
class_name NPCPeerManager

#=== Constants ===
## 单次请求的最大重试次数
const MAX_RETRIES: int = 5

#=== Variables ===
## 关联的游戏状态
var _game_state: GameState
## 玩家 id → Agent
var _agents: Dictionary[int, Agent] = {}
## 玩家 id → 已重试次数
var _retry_counts: Dictionary[int, int] = {}
## 玩家 id → 决策序列号（用于忽略过期回调）
var _decision_serial: Dictionary[int, int] = {}

#=== Signals ===
## 操作请求信号（期望监听者处理）
## @requester
signal operation_requested(request: OperationRequest)

#=== Constructor ===
## 构造函数
## @internal
func _init(game_state: GameState) -> void:
	_game_state = game_state
	_game_state.player_manager.player_added.connect(_on_player_added)

#=== Public Methods ===
## 当权限更新时，尝试为相关玩家发送 NPC 请求
## @internal
func on_permissions_updated(player_ids: PackedInt32Array) -> void:
	for player_id in player_ids:
		_try_send_npc_request(player_id)
## 清理所有 Agent 与请求状态
## @internal
func clear() -> void:
	_agents.clear()
	_retry_counts.clear()
	_decision_serial.clear()
## 发射操作请求信号（供外部监听）
## @emitter
func emit_operation_requested(request: OperationRequest) -> void:
	operation_requested.emit(request)

#=== Private Methods ===
## 玩家添加回调（仅当为 AI 玩家时创建 Agent）
## @internal
func _on_player_added(player: Player) -> void:
	if player.peer_id != PlayersManager.ai_peer_id:
		return
	var player_id: int = player.get_id()
	if _agents.has(player_id):
		return
	_agents[player_id] = Agent.new()
## 请求取消时的重试逻辑
## @internal
func _on_request_cancelled(player_id: int) -> void:
	var count: int = _retry_counts.get(player_id, 0)
	if count < MAX_RETRIES:
		_retry_counts[player_id] = count + 1
		call_deferred(&"_retry_request", player_id)
		return
	var abandon_req: OperationRequest = OperationRequest.AbandonResponse.new(player_id).use_npc_peer_id()
	_retry_counts.erase(player_id)
	call_deferred(&"emit_operation_requested", abandon_req)
## 重试请求
## @internal
func _retry_request(player_id: int) -> void:
	if not _agents.has(player_id):
		return
	_request_decision_async(player_id)
## 尝试发送 NPC 请求（等待 Agent 就绪）
## @internal
func _try_send_npc_request(player_id: int) -> void:
	if not _agents.has(player_id):
		return
	await _await_agent_ready()
	_retry_counts.erase(player_id)
	_request_decision_async(player_id)
## 等待 NPC 就绪（简单延时）
func _await_agent_ready() -> void:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	if scene_tree:
		await scene_tree.create_timer(1.0).timeout
## 异步请求决策
## @internal
func _request_decision_async(player_id: int) -> void:
	var serial: int = _decision_serial.get(player_id, 0) + 1
	_decision_serial[player_id] = serial
	var data: NPCDecisionData = _build_decision_data(player_id)
	data.is_npc = true
	_agents[player_id].request_decision_async(data, func(request: OperationRequest):
		_on_npc_decision(player_id, serial, request)
	)
## NPC 决策回调
## @internal
func _on_npc_decision(player_id: int, serial: int, request: OperationRequest) -> void:
	if _decision_serial.get(player_id) != serial:
		return
	_decision_serial.erase(player_id)
	if request == null:
		request = OperationRequest.AbandonResponse.new(player_id).use_npc_peer_id()
	request.cancelled.connect(_on_request_cancelled.bind(player_id), CONNECT_ONE_SHOT)
	emit_operation_requested(request)
## 构造系统层决策快照（主线程调用，纯数据）
## @external
func _build_decision_data(player_id: int) -> NPCDecisionData:
	var data: NPCDecisionData = NPCDecisionData.new()
	data.player_id = player_id
	# 系统侧回合重置尚未接线，攻击标记按现状恒为 false
	data.has_attacked_in_main = false
	data.current_stage_name = _game_state.get_current_active_stage_name()
	var self_player: Player = _game_state.player_manager.get_player_by_id(player_id)
	if self_player:
		var hand_area: AreaHand = _game_state.get_hand_area(player_id)
		if hand_area:
			for card in hand_area.get_all_cards():
				data.hand_cards.append({&"id": card.id, &"type": card.type})
		var defense_area: AreaDefence = _game_state.get_defense_area(player_id)
		data.defense_area_empty = (defense_area == null or defense_area.is_empty())
		data.self_speed = self_player.get_attribute(&"speed")
	else:
		data.defense_area_empty = true
		data.self_speed = 0
	if data.current_stage_name == &"DefenseBattle":
		var defense_stage: StageDefense = _get_defense_stage()
		if defense_stage:
			data.defense_stage_owner_id = defense_stage.defender.get_id()
			data.is_responsive = (defense_stage.current_responsive_player_id == player_id)
		else:
			data.is_responsive = false
	else:
		data.is_responsive = true
	var others: PackedInt32Array = PackedInt32Array()
	for p in _game_state.player_manager.players:
		if p.get_id() != player_id:
			others.append(p.get_id())
			var settle_count: int = 0
			var def_area: AreaDefence = _game_state.get_defense_area(p.get_id())
			if def_area:
				settle_count = def_area.settle_count
			data.other_players_settle_counts[p.get_id()] = settle_count
	data.other_player_ids = others
	return data
## 获取当前守区攻防阶段实例
func _get_defense_stage() -> StageDefense:
	if not _game_state.stage_manager:
		return null
	var cur_stage: Stage = _game_state.stage_manager.current_stage
	return cur_stage as StageDefense if cur_stage is StageDefense else null
