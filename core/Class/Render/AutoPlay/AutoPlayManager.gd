## 渲染端 AI 托管控制器：以 CTRL 切换本地玩家托管；
## 复用 [Agent] 的决策能力，经传输层上传请求，并按网络往返与渲染队列延迟节流与重试。
extends Node
class_name AutoPlayManager

#== Inner Classes ==
## 单次决策的局势快照
class Situation:
	## 是否具备托管决策条件（本地玩家、手牌区与连接就绪）
	var ready: bool = false
	## 局势指纹：阶段、行动玩家、手牌或守区变化都会改变它
	var key: String = ""
	## 当前阶段名
	var stage_name: StringName = &""

#== Constants ==
## 托管轮询间隔（帧）
const TICK_FRAME_INTERVAL: int = 6
## 两次发送之间的最小冷却（毫秒）
const SEND_COOLDOWN_MS: int = 250
## 状态变化后的稳定等待（毫秒），覆盖网络往返与渲染请求队列延迟
const SETTLE_DELAY_MS: int = 600
## 单次请求的基础观察窗口（毫秒）
const IN_FLIGHT_TIMEOUT_MS: int = 2000
## 每次重试追加的观察时间（毫秒）
const RETRY_BACKOFF_MS: int = 500
## 同一局势下最多发送次数
const MAX_SENDS_PER_SITUATION: int = 4
## 客户端不同步修饰后的速度属性，取玩家蓝图基础值
const ASSUMED_SPEED: int = 1
## 客户端不同步守区结算次数，取初始值
const ASSUMED_SETTLE_COUNT: int = 0
## 空守区顶层牌归属哨兵
const NO_TOP_CARD_OWNER: int = -1

#== Exports ==
## 渲染根节点
@export var render_control: RenderControl = null

#== Variables ==
## 渲染上下文
var _context: RenderContext = null
## 本地玩家 id
var _local_player_id: int = 0
## 决策代理
var _agent: Agent = Agent.new()
## 托管开关
var _enabled: bool = false
## 当前局势指纹
var _situation_key: String = ""
## 当前局势最近变化时刻（毫秒）
var _situation_changed_msec: int = 0
## 是否等待已上传请求的响应
var _in_flight: bool = false
## 观察窗口起始时刻（毫秒）
var _in_flight_started_msec: int = 0
## 上次发送时刻（毫秒）
var _last_send_msec: int = 0
## 当前局势内已发送次数
var _send_count: int = 0
## 决策请求代数：丢弃线程返回的过期结果
var _request_serial: int = 0
## 是否有决策线程在计算
var _decision_pending: bool = false
## 本回合主阶段是否已攻击
var _attacked_in_main: bool = false

#== Lifecycle ==
## 就绪：解析渲染根节点并提示开关按键
func _ready() -> void:
	if render_control == null and get_parent() is RenderControl:
		render_control = get_parent() as RenderControl
	if render_control == null:
		return
	_context = render_control.render_context
	GlobalConsole._print("AI托管：按 CTRL 切换（渲染端，经 Agent 决策）")

## 每 TICK_FRAME_INTERVAL 帧驱动一次托管节拍
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

#== Public Methods ==
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
	_reset_runtime_state()
	if enabled:
		GlobalConsole._print("AI托管：已开启")
		return
	GlobalConsole._print("AI托管：已关闭")

## 卡牌类型序号转常量名；不依赖动态常量表，客户端未注册常量时也可用
## @pure
static func get_card_type_name(type_index: int) -> StringName:
	if type_index < 0 or type_index >= GlobalConstants.CARD_TYPES.size():
		return GlobalConstants.DefaultCard.NULL
	return GlobalConstants.CARD_TYPES[type_index]

## 取指定玩家守区顶层牌的归属玩家 id（空守区返回哨兵）
## @pure
static func get_defense_top_card_owner(context: RenderContext, player_id: int) -> int:
	var defense_area: RenderArea = context.get_render_area(GlobalConstants.DefaultArea.DEFENCE, player_id)
	if not (defense_area is ItemRenderArea):
		return NO_TOP_CARD_OWNER
	var item_area: ItemRenderArea = defense_area as ItemRenderArea
	for index: int in range(item_area.items_pool.size() - 1, -1, -1):
		var item: RenderItem = item_area.items_pool[index]
		if item == null or item.data == null:
			continue
		var card_pack: CardPack = item.data as CardPack
		if card_pack == null:
			continue
		return card_pack.player_id
	return NO_TOP_CARD_OWNER

## 判断指定玩家在当前阶段是否持有响应权（镜像系统层响应权规则）
## @pure
static func is_responsive(context: RenderContext, player_id: int, stage_name: StringName) -> bool:
	if context == null or player_id <= 0:
		return false
	var state_manager: RenderStateManager = context.state_manager
	match stage_name:
		&"Main":
			return state_manager.main_stage_player_id == player_id
		&"Discard":
			return get_hand_card_count(context, player_id) > get_hand_limit(context, player_id)
		&"DefenseBattle":
			return is_responsive_in_defense(context, player_id)
	return false

## 取手牌区当前卡牌数（其他玩家的手牌不同步，仅本地玩家可读）
## @pure
static func get_hand_card_count(context: RenderContext, player_id: int) -> int:
	var hand_area: RenderArea = context.get_render_area(GlobalConstants.DefaultArea.HAND, player_id)
	if hand_area == null:
		return 0
	return hand_area.get_item_count()

## 估算指定玩家手牌上限（基础值；临时加成不在同步范围）
## @pure
static func get_hand_limit(context: RenderContext, player_id: int) -> int:
	var mp: int = PlayerPack.STANDARD_MP
	var players_area: RenderArea = context.get_render_area(GlobalConstants.DefaultArea.PLAYERS)
	if players_area is ItemRenderArea:
		var player_area: ItemRenderArea = players_area as ItemRenderArea
		for item: RenderItem in player_area.items_pool:
			if item == null or item.data == null:
				continue
			var player_pack: PlayerPack = item.data as PlayerPack
			if player_pack == null or player_pack.get_id() != player_id:
				continue
			mp = player_pack.MP
			break
	return ceili(float(mp) / 4.0)

## 判断守区攻防阶段指定玩家是否持有响应权
## @pure
static func is_responsive_in_defense(context: RenderContext, player_id: int) -> bool:
	var state_manager: RenderStateManager = context.state_manager
	var defender_id: int = state_manager.temp_stage_owner_id
	if defender_id <= 0:
		return false
	var attacker_id: int = state_manager.main_stage_player_id
	var top_owner_id: int = get_defense_top_card_owner(context, defender_id)
	var responsive_id: int = attacker_id
	if top_owner_id != NO_TOP_CARD_OWNER and top_owner_id != defender_id:
		responsive_id = defender_id
	return responsive_id == player_id

#== Private Methods ==
## 单次托管节拍：观察网络与局势，必要时请求决策并上传请求
## @side_effect
func _tick() -> void:
	if _context == null or not _is_connection_ready():
		_abort_in_flight()
		return
	var situation: Situation = _build_situation()
	if situation.key != _situation_key:
		_apply_situation_change(situation)
	if not situation.ready:
		return
	if _decision_pending:
		return
	if _in_flight:
		_tick_in_flight()
		return
	if not is_responsive(_context, _local_player_id, situation.stage_name):
		return
	if not _should_act(situation):
		return
	var now: int = Time.get_ticks_msec()
	if now - _situation_changed_msec < SETTLE_DELAY_MS:
		return
	if now - _last_send_msec < SEND_COOLDOWN_MS:
		return
	if _send_count >= MAX_SENDS_PER_SITUATION:
		return
	_request_decision()

## 观察窗口到期则放弃等待，允许重试
## @side_effect
func _tick_in_flight() -> void:
	var timeout: int = IN_FLIGHT_TIMEOUT_MS + _send_count * RETRY_BACKOFF_MS
	if Time.get_ticks_msec() - _in_flight_started_msec < timeout:
		return
	_in_flight = false

## 请求一次异步决策；结果由回调校验后上传
## @side_effect
func _request_decision() -> void:
	_decision_pending = true
	_request_serial += 1
	var serial: int = _request_serial
	var request_key: String = _situation_key
	var data: NPCDecisionData = _build_decision_data()
	_agent.request_decision_async(data, func(request: OperationRequest):
		_on_decision(serial, request_key, request)
	)

## 决策回调：校验代数与局势后上传操作请求
## @side_effect
func _on_decision(serial: int, request_key: String, request: OperationRequest) -> void:
	_decision_pending = false
	if serial != _request_serial or not _enabled:
		return
	if request_key != _situation_key or request == null:
		return
	if not _is_connection_ready():
		return
	_mark_attack_if_needed(request)
	render_control.transport.upload_operation_request(request)
	_in_flight = true
	_in_flight_started_msec = Time.get_ticks_msec()
	_last_send_msec = _in_flight_started_msec
	_send_count += 1
	GlobalConsole._print(["AI托管：已上传请求：", request.get_class_name()])

## 局势变化：刷新观察窗口与重试计数，并维护回合内攻击标记
## @side_effect
func _apply_situation_change(situation: Situation) -> void:
	_situation_key = situation.key
	_situation_changed_msec = Time.get_ticks_msec()
	_in_flight = false
	_send_count = 0
	_request_serial += 1
	if situation.stage_name == &"Start":
		_attacked_in_main = false

## 构造当前托管局势快照
## @side_effect
func _build_situation() -> Situation:
	var situation: Situation = Situation.new()
	var local_player_id: int = _context.area_manager.local_player_id
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
		str(_get_hand_card_ids(hand_area as ItemRenderArea)),
		_get_self_defense_count(),
		defense_key,
	]
	situation.ready = true
	return situation

## 构造渲染侧决策快照（纯数据，主线程调用）
## @external
func _build_decision_data() -> NPCDecisionData:
	var data: NPCDecisionData = NPCDecisionData.new()
	data.player_id = _local_player_id
	data.has_attacked_in_main = _attacked_in_main
	data.current_stage_name = _context.get_current_stage_name()
	data.self_speed = ASSUMED_SPEED
	_fill_hand_cards(data)
	_fill_self_defense(data)
	_fill_other_players(data)
	_fill_defense_stage(data)
	return data

## 填充手牌快照：类型转回常量名以复用决策树的比较
## @external
func _fill_hand_cards(data: NPCDecisionData) -> void:
	var hand_area: RenderArea = _context.get_render_area(GlobalConstants.DefaultArea.HAND)
	if not (hand_area is ItemRenderArea):
		return
	var item_area: ItemRenderArea = hand_area as ItemRenderArea
	for item: RenderItem in item_area.items_pool:
		if item == null or item.data == null:
			continue
		var card_pack: CardPack = item.data as CardPack
		if card_pack == null:
			continue
		data.hand_cards.append({&"id": card_pack.get_id(), &"type": get_card_type_name(card_pack.type)})

## 填充本地守区是否为空
## @external
func _fill_self_defense(data: NPCDecisionData) -> void:
	var defense_area: RenderArea = _context.get_render_area(GlobalConstants.DefaultArea.DEFENCE)
	data.defense_area_empty = defense_area == null or defense_area.get_item_count() == 0

## 填充其他玩家 id 与守区结算次数（结算次数不在同步范围，取初始值）
## @external
func _fill_other_players(data: NPCDecisionData) -> void:
	var players_area: RenderArea = _context.get_render_area(GlobalConstants.DefaultArea.PLAYERS)
	if not (players_area is ItemRenderArea):
		return
	var item_area: ItemRenderArea = players_area as ItemRenderArea
	for item: RenderItem in item_area.items_pool:
		if item == null or item.data == null:
			continue
		var player_pack: PlayerPack = item.data as PlayerPack
		if player_pack == null or player_pack.get_id() == _local_player_id:
			continue
		var other_player_id: int = player_pack.get_id()
		data.other_player_ids.append(other_player_id)
		data.other_players_settle_counts[other_player_id] = ASSUMED_SETTLE_COUNT

## 填充守区攻防阶段的归属玩家与响应权
## @external
func _fill_defense_stage(data: NPCDecisionData) -> void:
	if data.current_stage_name != &"DefenseBattle":
		data.is_responsive = true
		return
	data.defense_stage_owner_id = _context.state_manager.temp_stage_owner_id
	data.is_responsive = is_responsive(_context, _local_player_id, data.current_stage_name)

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

## 中止观察窗口（连接或上下文不可用）
## @side_effect
func _abort_in_flight() -> void:
	_in_flight = false
	_decision_pending = false

## 重置托管运行态
## @side_effect
func _reset_runtime_state() -> void:
	_situation_key = ""
	_situation_changed_msec = 0
	_in_flight = false
	_in_flight_started_msec = 0
	_last_send_msec = 0
	_send_count = 0
	_request_serial += 1
	_decision_pending = false
	_attacked_in_main = false

## 判断多人连接是否可用
## @pure
func _is_connection_ready() -> bool:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null:
		return false
	return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

## 取本地手牌 id 序列，用于局势指纹
func _get_hand_card_ids(hand_area: ItemRenderArea) -> PackedInt32Array:
	var ids: PackedInt32Array = []
	for item: RenderItem in hand_area.items_pool:
		if item == null or item.data == null:
			continue
		ids.append(item.data.get_id())
	return ids

## 取本地守区卡牌数
func _get_self_defense_count() -> int:
	var defense_area: RenderArea = _context.get_render_area(GlobalConstants.DefaultArea.DEFENCE)
	if defense_area == null:
		return 0
	return defense_area.get_item_count()

## 取指定玩家守区的局势指纹：卡牌数与顶层牌归属
func _build_defense_key(player_id: int) -> String:
	var defense_area: RenderArea = _context.get_render_area(GlobalConstants.DefaultArea.DEFENCE, player_id)
	var count: int = defense_area.get_item_count() if defense_area else 0
	var top_owner_id: int = get_defense_top_card_owner(_context, player_id)
	return "%d:%d" % [count, top_owner_id]

## 按牌 id 取本地手牌类型名；不在手牌中返回空
func _get_hand_card_type(card_id: int) -> StringName:
	var hand_area: RenderArea = _context.get_render_area(GlobalConstants.DefaultArea.HAND)
	if not (hand_area is ItemRenderArea):
		return &""
	var item_area: ItemRenderArea = hand_area as ItemRenderArea
	for item: RenderItem in item_area.items_pool:
		if item == null or item.data == null:
			continue
		var card_pack: CardPack = item.data as CardPack
		if card_pack == null or card_pack.get_id() != card_id:
			continue
		return get_card_type_name(card_pack.type)
	return &""
