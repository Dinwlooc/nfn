## 渲染端 AI 托管控制器：以 CTRL 切换本地玩家托管；
## 复用 [Agent] 的决策能力，经传输层上传请求，节流与重试由 [AutoPlayThrottleManager] 承担。
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
## 节流与重试状态机
var _gate: AutoPlayThrottleManager = AutoPlayThrottleManager.new()
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
	_gate.reset()
	_decision_pending = false
	_attacked_in_main = false
	if enabled:
		GlobalConsole._print("AI托管：已开启")
		return
	GlobalConsole._print("AI托管：已关闭")

#== Private Methods ==
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
	render_control.transport.upload_operation_request(request)
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
func _build_defense_key(player_id: int) -> String:
	var count: int = _context.get_defense_card_count(player_id)
	var top_owner_id: int = _context.get_defense_top_card_owner(player_id)
	return "%d:%d" % [count, top_owner_id]

## 按牌 id 取本地手牌类型名；不在手牌中返回空
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
