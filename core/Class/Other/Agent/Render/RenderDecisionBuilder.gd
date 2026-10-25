## 渲染侧决策构造器（渲染层模块）：经 [RenderContext] 门面取数，装配 [NPCDecisionData]；
## 与系统层 [AgentManager] 的快照构造结构对称。响应权规则镜像留于此处，
## 系统层日后经同步暴露答案时可整行删除。
## 纯静态工具类：不持状态、不接触游戏状态，只读渲染上下文门面。
extends RefCounted
class_name RenderDecisionBuilder

#== Public Methods ==
## 卡牌类型序号转常量名；不依赖动态常量表，客户端未注册常量时也可用
## @pure
static func get_card_type_name(type_index: int) -> StringName:
	if type_index < 0 or type_index >= GlobalConstants.CARD_TYPES.size():
		return GlobalConstants.DefaultCard.NULL
	return GlobalConstants.CARD_TYPES[type_index]

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
			return context.get_hand_card_count(player_id) > context.get_hand_limit(player_id)
		&"DefenseBattle":
			return is_responsive_in_defense(context, player_id)
	return false

## 判断守区攻防阶段指定玩家是否持有响应权
## @pure
static func is_responsive_in_defense(context: RenderContext, player_id: int) -> bool:
	var state_manager: RenderStateManager = context.state_manager
	var defender_id: int = state_manager.temp_stage_owner_id
	if defender_id <= 0:
		return false
	var attacker_id: int = state_manager.main_stage_player_id
	var top_owner_id: int = context.get_defense_top_card_owner(defender_id)
	var responsive_id: int = attacker_id
	if top_owner_id != 0 and top_owner_id != defender_id:
		responsive_id = defender_id
	return responsive_id == player_id

## 构造渲染侧决策快照（纯数据，主线程调用）
## @external
static func build(context: RenderContext, player_id: int, attacked_in_main: bool) -> NPCDecisionData:
	var data: NPCDecisionData = NPCDecisionData.new()
	data.player_id = player_id
	data.has_attacked_in_main = attacked_in_main
	data.current_stage_name = context.get_current_stage_name()
	data.self_speed = context.get_player_speed(player_id)
	_fill_hand_cards(context, data)
	_fill_self_defense(context, data)
	_fill_other_players(context, player_id, data)
	_fill_defense_stage(context, player_id, data)
	return data

#== Private Methods ==
## 填充手牌快照：类型转回常量名以复用决策树的比较
## @internal
static func _fill_hand_cards(context: RenderContext, data: NPCDecisionData) -> void:
	var hand_area: ItemRenderArea = context.get_hand_area()
	if hand_area == null:
		return
	for item: RenderItem in hand_area.items_pool:
		if item == null or item.data == null:
			continue
		var card_pack: CardPack = item.data as CardPack
		if card_pack == null:
			continue
		data.hand_cards.append({&"id": card_pack.get_id(), &"type": get_card_type_name(card_pack.type)})

## 填充本地守区是否为空
## @internal
static func _fill_self_defense(context: RenderContext, data: NPCDecisionData) -> void:
	data.defense_area_empty = context.get_defense_card_count() == 0

## 填充其他玩家 id 与守区结算次数（结算次数同步自守区渲染区）
## @internal
static func _fill_other_players(context: RenderContext, player_id: int, data: NPCDecisionData) -> void:
	var players_area: ItemRenderArea = context.get_players_area()
	if players_area == null:
		return
	for item: RenderItem in players_area.items_pool:
		if item == null or item.data == null:
			continue
		var player_pack: PlayerPack = item.data as PlayerPack
		if player_pack == null or player_pack.get_id() == player_id:
			continue
		var other_player_id: int = player_pack.get_id()
		data.other_player_ids.append(other_player_id)
		data.other_players_settle_counts[other_player_id] = context.get_settle_count(other_player_id)

## 填充守区攻防阶段的归属玩家与响应权
## @internal
static func _fill_defense_stage(context: RenderContext, player_id: int, data: NPCDecisionData) -> void:
	if data.current_stage_name != &"DefenseBattle":
		data.is_responsive = true
		return
	data.defense_stage_owner_id = context.state_manager.temp_stage_owner_id
	data.is_responsive = is_responsive(context, player_id, data.current_stage_name)
