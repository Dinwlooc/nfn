## Agent 管理器（插件层）：单节点承载系统层与渲染层两套 AI 决策快照构建模块。
## System 层模块：[method initialize_system]（原 NPCPeerManager）——为 AI 玩家构造系统层决策快照，调度 [Agent] 决策并转发操作请求；
## Render 层模块：[method initialize_render]（原 AutoPlayManager）——以 CTRL 切换本地玩家托管，复用 [Agent] 决策，经传输层上传请求，节流与重试由 [AutoPlayThrottleManager] 承担。
## 就绪时经 [GlobalRegistry] 注册（AGENT_MANAGER_TYPE）：系统层由 [AgentTrigger] 从注册表取用并接线到系统层；渲染层无触发器概念，由 [RenderControl] 直接部署。
extends Node
class_name AgentManager

#== Constants ==
## 托管轮询间隔（帧）
const TICK_FRAME_INTERVAL: int = 6
## 单次系统层请求的最大重试次数
const MAX_RETRIES: int = 5

#== Signals ==
## 系统层操作请求信号（由 [AgentTrigger] 接线到操作处理器）
## @requester
signal operation_requested(request: OperationRequest)

#== Exports ==
#（无：渲染根与游戏状态分别由部署方注入，不再走场景导出）

#== Variables ==
#--- System 层快照构建模块 ---
## 是否已完成系统层模块初始化
var _system_initialized: bool = false
## 关联的游戏状态
var _game_state: GameState
## 玩家 id → Agent
var _agents: Dictionary[int, Agent] = {}
## 玩家 id → 已重试次数
var _retry_counts: Dictionary[int, int] = {}
## 玩家 id → 决策序列号（用于忽略过期回调）
var _decision_serial: Dictionary[int, int] = {}

#--- Render 层快照构建模块 ---
## 是否已完成渲染层模块初始化
var _render_initialized: bool = false
## 渲染根节点
var _render_control: RenderControl = null
## 渲染上下文
var _context: RenderContext = null
## 本地玩家 id
var _local_player_id: int = 0
## 决策代理
var _agent: Agent = Agent.new()
## 托管开关
var _enabled: bool = false
## 节流与重试状态机
var _gate: AutoPlayThrottleManager = AutoPlayThrottleManager.new()
## 是否有决策线程在计算
var _decision_pending: bool = false
## 本回合主阶段是否已攻击
var _attacked_in_main: bool = false

## 单次决策的局势快照
class Situation:
	## 是否具备托管决策条件（本地玩家、手牌区与连接就绪）
	var ready: bool = false
	## 局势指纹：阶段、行动玩家、手牌或守区变化都会改变它
	var key: String = ""
	## 当前阶段名
	var stage_name: StringName = &""

#== Lifecycle ==
## 就绪：渲染层模块未初始化前不参与帧处理；注册须在禁用之后——
## 注册表信号会在本调用栈内同步触发 initialize_render（经 RenderControl 的订阅回调），
## 反过来会覆盖这里的禁用状态
func _ready() -> void:
	set_process(false)
	set_process_unhandled_input(false)
	GlobalRegistry.register_singleton(GlobalRegistry.AGENT_MANAGER_TYPE, self)

## 退出场景树时注销，防止注册表残留悬空引用
func _exit_tree() -> void:
	GlobalRegistry.unregister_singleton(GlobalRegistry.AGENT_MANAGER_TYPE)

#== Public Methods ==
#--- 模块初始化 ---
## 初始化 System 层快照构建模块：补齐既有 AI 玩家并订阅玩家添加信号
## @side_effect
func initialize_system(game_state: GameState) -> void:
	if _system_initialized:
		return
	_system_initialized = true
	_game_state = game_state
	# 补齐触发器接线前已存在的 AI 玩家（防早期事件丢失）
	for player in game_state.player_manager.players:
		_ensure_agent(player)
	game_state.player_manager.player_added.connect(_on_player_added)

## 初始化 Render 层快照构建模块：解析渲染根节点并启用托管节拍
## @side_effect
func initialize_render(render_control: RenderControl) -> void:
	if _render_initialized:
		return
	if render_control == null:
		return
	_render_initialized = true
	_render_control = render_control
	_context = render_control.render_context
	if _context != null:
		set_process(true)
		set_process_unhandled_input(true)
	GlobalConsole._print("AI托管：按 CTRL 切换（渲染端，经 Agent 决策）")

#--- System 层接口 ---
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

#--- Render 层接口 ---
## 取托管开关状态
## @pure
func is_enabled() -> bool:
	return _enabled

## 切换托管开关
## @delegates(set_enabled)
func toggle() -> void:
	set_enabled(not _enabled)

## 启停托管并重置运行态
## @side_effect
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	_gate.reset()
	_decision_pending = false
	_attacked_in_main = false
	if enabled:
		GlobalConsole._print("AI托管：已开启")
		return
	GlobalConsole._print("AI托管：已关闭")

#== Private Methods ==
#--- System 层快照构建模块 ---
## 玩家添加回调（仅当为 AI 玩家时创建 Agent）
## @internal
func _on_player_added(player: Player) -> void:
	_ensure_agent(player)
## 确保该 AI 玩家持有 Agent（重复调用安全）
## @internal
func _ensure_agent(player: Player) -> void:
	if player.peer_id != PlayersManager.ai_peer_id:
		return
	var player_id: int = player.get_id()
	if _agents.has(player_id):
		return
	_agents[player_id] = Agent.new()
## 请求取消时的重试逻辑（取消信号携带请求自身）
## @internal
func _on_request_cancelled(request: OperationRequest) -> void:
	var player_id: int = request.source_player_id
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
## @internal
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
	request.cancelled.connect(_on_request_cancelled, CONNECT_ONE_SHOT)
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

#--- Render 层快照构建模块 ---
## 每 TICK_FRAME_INTERVAL 帧驱动一次托管节拍
## @internal
func _process(_delta: float) -> void:
	if not _enabled:
		return
	if Engine.get_process_frames() % TICK_FRAME_INTERVAL != 0:
		return
	_tick()

## 输入回调：CTRL 切换托管开关
## @override
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_CTRL and key_event.physical_keycode != KEY_CTRL:
		return
	toggle()
	get_viewport().set_input_as_handled()

## 单次托管节拍：观察网络与局势，必要时请求决策并上传请求
## @side_effect
func _tick() -> void:
	if _context == null or not _is_connection_ready():
		_gate.abort()
		_decision_pending = false
		return
	var situation: Situation = _build_situation()
	if situation.key != _gate.get_situation_key():
		_apply_situation_change(situation)
	if not situation.ready:
		return
	if _decision_pending:
		return
	if _gate.is_in_flight() and not _gate.tick_in_flight(Time.get_ticks_msec()):
		return
	if not RenderDecisionBuilder.is_responsive(_context, _local_player_id, situation.stage_name):
		return
	if not _should_act(situation):
		return
	if not _gate.can_send(Time.get_ticks_msec(), situation.key):
		return
	_request_decision()

## 请求一次异步决策；结果由回调校验后上传
## @side_effect
func _request_decision() -> void:
	_decision_pending = true
	var serial: int = _gate.advance_serial()
	var request_key: String = _gate.get_situation_key()
	var data: NPCDecisionData = RenderDecisionBuilder.build(_context, _local_player_id, _attacked_in_main)
	_agent.request_decision_async(data, func(request: OperationRequest):
		_on_decision(serial, request_key, request)
	)

## 决策回调：校验代数与局势后上传操作请求
## @side_effect
func _on_decision(serial: int, request_key: String, request: OperationRequest) -> void:
	_decision_pending = false
	if serial != _gate.get_serial() or not _enabled:
		return
	if request_key != _gate.get_situation_key() or request == null:
		return
	if not _is_connection_ready():
		return
	_mark_attack_if_needed(request)
	_render_control.transport.upload_operation_request(request)
	_gate.on_sent(Time.get_ticks_msec())
	GlobalConsole._print(["AI托管：已上传请求：", request.get_class_name()])

## 局势变化：刷新节拍门，并维护回合内攻击标记
## @side_effect
func _apply_situation_change(situation: Situation) -> void:
	_gate.on_situation_changed(situation.key)
	if situation.stage_name == &"Start":
		_attacked_in_main = false

## 构造当前托管局势快照
## @side_effect
func _build_situation() -> Situation:
	var situation: Situation = Situation.new()
	var local_player_id: int = _context.get_local_player_id()
	if local_player_id <= 0:
		return situation
	_local_player_id = local_player_id
	var hand_area: RenderArea = _context.get_render_area(GlobalConstants.DefaultArea.HAND)
	if not (hand_area is ItemRenderArea):
		return situation
	var state_manager: RenderStateManager = _context.state_manager
	situation.stage_name = _context.get_current_stage_name()
	var defense_key: String = "%d" % state_manager.temp_stage_owner_id
	if situation.stage_name == &"DefenseBattle":
		defense_key = _build_defense_key(state_manager.temp_stage_owner_id)
	situation.key = "%s|%d|%d|%s|%d|%s" % [
		situation.stage_name,
		state_manager.main_stage_player_id,
		state_manager.temp_stage_owner_id,
		str(_context.get_hand_card_ids()),
		_context.get_defense_card_count(),
		defense_key,
	]
	situation.ready = true
	return situation

## 判断当前局势是否应继续主动决策（主阶段攻击只做一次）
## @pure
func _should_act(situation: Situation) -> bool:
	if situation.stage_name != &"Main":
		return true
	return not _attacked_in_main

## 记录主阶段攻击：出牌类型为攻击牌时置位
## @side_effect
func _mark_attack_if_needed(request: OperationRequest) -> void:
	if not (request is OperationRequest.PlayCard):
		return
	if _context.get_current_stage_name() != &"Main":
		return
	var play_request: OperationRequest.PlayCard = request as OperationRequest.PlayCard
	if _get_hand_card_type(play_request.get_card_id()) != GlobalConstants.DefaultCard.ATTACK:
		return
	_attacked_in_main = true

## 判断多人连接是否可用
## @pure
func _is_connection_ready() -> bool:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null:
		return false
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

## 取指定玩家守区的局势指纹：卡牌数与顶层牌归属
## @pure
func _build_defense_key(player_id: int) -> String:
	var count: int = _context.get_defense_card_count(player_id)
	var top_owner_id: int = _context.get_defense_top_card_owner(player_id)
	return "%d:%d" % [count, top_owner_id]

## 按牌 id 取本地手牌类型名；不在手牌中返回空
## @pure
func _get_hand_card_type(card_id: int) -> StringName:
	var hand_area: ItemRenderArea = _context.get_hand_area()
	if hand_area == null:
		return &""
	for item: RenderItem in hand_area.items_pool:
		if item == null or item.data == null:
			continue
		var card_pack: CardPack = item.data as CardPack
		if card_pack == null or card_pack.get_id() != card_id:
			continue
		return RenderDecisionBuilder.get_card_type_name(card_pack.type)
	return &""
