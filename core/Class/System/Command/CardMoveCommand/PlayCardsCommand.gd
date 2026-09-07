extends CardMoveCommand
class_name PlayCardsCommand

class Context extends CardMoveCommand.Context:
	enum TargetAreaType { CENTER, PLAYER_DEF }
	var target_player_id: int = 0
	var target_area_type: TargetAreaType = TargetAreaType.PLAYER_DEF
	var card_ids: PackedInt32Array = PackedInt32Array()
	var ap_source_player: Player = null

	func set_ap_source_player(player: Player) -> void:
		ap_source_player = player
	func set_target_player_id(id: int) -> void:
		target_player_id = id
	func set_target_area_type(area_type: TargetAreaType) -> void:
		target_area_type = area_type
	func set_card_ids(ids: PackedInt32Array) -> void:
		card_ids = ids
	func are_card_ids_valid() -> bool:
		return card_ids.size() > 0

## 静态初始化：校验并设置源区域、目标区域.
static func init(context: Context, game_state: GameState) -> void:
	var source_player: Player = context.get_source_player()
	if BehaviorCommand.fail_if_null(source_player, context, "源玩家无效"): return
	var hand_area: AreaHand = game_state.get_hand_area(source_player.get_id())
	if BehaviorCommand.fail_if_null(hand_area, context, "无法获取源玩家手牌区域"): return
	context.source_area = hand_area
	match context.target_area_type:
		Context.TargetAreaType.CENTER:
			var center_area: AreaCenter = game_state.get_center_area()
			if BehaviorCommand.fail_if_null(center_area, context, "无法获取中央区"): return
			var target_player: Player = game_state.player_manager.get_player_by_id(context.target_player_id)
			if BehaviorCommand.fail_if_null(target_player, context, "无效的目标玩家ID"): return
			center_area.set_skill_targets([target_player])
			context.target_area = center_area
		Context.TargetAreaType.PLAYER_DEF:
			var def_area: AreaDefence = game_state.get_defense_area(context.target_player_id)
			if BehaviorCommand.fail_if_null(def_area, context, "无法获取目标玩家守备区域"): return
			context.target_area = def_area
		_:
			BehaviorCommand.fail(context, "无效的目标区域类型")
			return
	context.set_id_mode(context.card_ids)

## 构建行动点消耗伴生命令（若消耗 > 0），返回命令或 null
static func build_ap_companion(context: Context) -> ActionPointCommand:
	if not context.ap_source_player:
		return null
	if not context.source_area:
		return null
	var cards: Array[Card] = context.source_area.get_cards_by_ids(context.card_ids)
	var total_cost: int = 0
	for card in cards:
		total_cost += card.get_attribute(&"cost")
	if total_cost <= 0:
		return null
	return ActionPointCommand.new(
		context.ap_source_player,
		total_cost,
		ActionPointCommand.Context.Operation.SUB,
		&"play_card"
	)

## @seam_override
func _init(
	player: Player,
	card_ids: PackedInt32Array,
	target_player_id: int,
	target_area_type: Context.TargetAreaType = Context.TargetAreaType.PLAYER_DEF,
	ap_source_player: Player = player,
	name_overriding: StringName = &"PlayCards",
	context_overriding = Context.new()
) -> void:
	super._init(player, name_overriding, context_overriding)
	_context.set_target_player_id(target_player_id)
	_context.set_target_area_type(target_area_type)
	_context.set_card_ids(card_ids)
	_context.set_ap_source_player(ap_source_player)
	_context.set_event_type(RenderRequest.ItemSet.EventType.TRANSFER)
## 伴生行动点消耗命令，但不依赖于它。
## @hook
func _on_init_phase(game_state: GameState, context_overriding: CardMoveCommand.Context = _context as Context) -> void:
	if context_overriding is not Context:
		BehaviorCommand.fail(context_overriding, "上下文类型错误")
		return
	PlayCardsCommand.init(context_overriding, game_state)
	var ap_cmd := PlayCardsCommand.build_ap_companion(context_overriding)
	if not ap_cmd:
		return
	append_companion_command(ap_cmd)
