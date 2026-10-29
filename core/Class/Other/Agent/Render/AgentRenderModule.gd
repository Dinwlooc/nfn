## Agent 渲染层快照构建模块：以 CTRL 切换本地玩家托管，复用 [Agent] 决策，
## 经传输层上传请求，节流与重试由 [AutoPlayThrottleManager] 承担。
## 原 AutoPlayManager 本体；由 [AgentManager] 实例化持有并转发节拍与输入，由 [RenderControl] 直接部署。
extends RefCounted
class_name AgentRenderModule

#== Constants ==
## 托管轮询间隔（帧）
const TICK_FRAME_INTERVAL: int = 6

## 单次决策的局势快照
class Situation:
	## 是否具备托管决策条件（本地玩家、手牌区与连接就绪）
	var ready: bool = false
	## 局势指纹：阶段、行动玩家、手牌或守区变化都会改变它
	var key: String = ""
	## 当前阶段名
	var stage_name: StringName = &""

#== Variables ==
## 渲染根节点
var _render_control: RenderControl = null
## 渲染上下文
var _context: RenderContext = null
## 本地玩家 id
var _local_player_id: int = 0
## 决策代理
var _agent: Agent = AutoAgent.new()
## 托管开关
var _enabled: bool = false
## 节流与重试状态机
var _gate: AutoPlayThrottleManager = AutoPlayThrottleManager.new()
## 是否有决策线程在计算
var _decision_pending: bool = false
## 本回合主阶段是否已攻击
var _attacked_in_main: bool = false

#== Public Methods ==
## 初始化模块：解析渲染根节点；就绪返回 true（上下文不可用时返回 false）
## @side_effect
func initialize(render_control: RenderControl) -> bool:
	if _render_control == render_control:
		return _context != null
	if render_control == null:
		return false
	_render_control = render_control
	_context = render_control.render_context
	if _context == null:
		return false
	GlobalConsole._print("AI托管：按 CTRL 切换（渲染端，经 Agent 决策）")
	return true

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

## 托管节拍入口：每 TICK_FRAME_INTERVAL 帧驱动一次（由 [AgentManager] 转发）
## @internal
func process_tick(_delta: float) -> void:
	if not _enabled:
		return
	if Engine.get_process_frames() % TICK_FRAME_INTERVAL != 0:
		return
	_tick()

## 输入入口：CTRL 切换托管开关；消费时返回 true（由 [AgentManager] 置为已处理）
## @internal
func unhandled_input(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	if key_event.keycode != KEY_CTRL and key_event.physical_keycode != KEY_CTRL:
		return false
	toggle()
	return true

#== Private Methods ==
## 单次托管节拍：观察局势，必要时请求决策并上传请求
## 上传是否可达由传输层负责，本模块不检查网络（决策只产出请求）
## @side_effect
func _tick() -> void:
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
	_mark_attack_if_needed(request)
	_render_control.transport.upload_operation_request(request)
	_gate.on_sent(Time.get_ticks_msec())
	GlobalConsole._print(["AI托管：已上传请求：", request.get_operation_name()])

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
	situation.stage_name = _context.get_current_stage_name()
	var defense_key: String = "%d" % _context.get_temp_stage_owner_id()
	if situation.stage_name == &"DefenseBattle":
		defense_key = _build_defense_key(_context.get_temp_stage_owner_id())
	situation.key = "%s|%d|%d|%s|%d|%s" % [
		situation.stage_name,
		_context.get_main_stage_player_id(),
		_context.get_temp_stage_owner_id(),
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
	if request.get_operation_name() != &"play_card":
		return
	if _context.get_current_stage_name() != &"Main":
		return
	var play_request: ItemsOperation = request as ItemsOperation
	if _get_hand_card_type(play_request.get_primary_id()) != GlobalConstants.DefaultCard.ATTACK:
		return
	_attacked_in_main = true

## 取指定玩家守区的局势指纹：卡牌数与顶层牌归属
## @pure
func _build_defense_key(player_id: int) -> String:
	var count: int = _context.get_defense_card_count(player_id)
	var top_owner_id: int = _context.get_defense_top_card_owner(player_id)
	return "%d:%d" % [count, top_owner_id]

## 按牌 id 取本地手牌类型名；不在手牌中返回空（StringName 以空串表缺失，非 null）
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
