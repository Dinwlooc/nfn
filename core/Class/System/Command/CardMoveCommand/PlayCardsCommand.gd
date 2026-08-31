extends CardMoveCommand
class_name PlayCardsCommand

## 出牌命令上下文类
## @context @deep_inherit
class Context extends CardMoveCommand.Context:
	enum TargetAreaType {
		CENTER,
		PLAYER_DEF
	}
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

## @hook @seam_override
func _on_init_phase(game_state: GameState, context_overriding: CardMoveCommand.Context = _context as Context) -> void:
	if context_overriding is not Context:
		_fail("上下文类型错误", context_overriding)
		return
	var source_player: Player = context_overriding.get_source_player()
	# 合并检查：卡牌ID、源玩家、源手牌区（利用短路确保 get_id 安全）
	if not (
		RuleGuard.has_valid_card_ids(context_overriding.card_ids, _guard_error, "无效的卡牌ID数组") and
		RuleGuard.has_valid_player(source_player, _guard_error, "源玩家无效") and
		RuleGuard.has_valid_area(game_state.get_hand_area(source_player.get_id()), _guard_error, "无法获取源玩家手牌区域")
	):
		_fail(_guard_error.text, context_overriding)
		return
	var source_area: AreaHand = game_state.get_hand_area(source_player.get_id())
	context_overriding.source_area = source_area
	# 行动点消耗
	if context_overriding.ap_source_player:
		var ap_player: Player = context_overriding.ap_source_player
		var cards: Array[Card] = source_area.get_cards_by_ids(context_overriding.card_ids)
		var total_cost: int = 0
		for card in cards:
			total_cost += card.get_attribute(&"cost")
		var ap_cmd := ActionPointCommand.new(
			ap_player,
			total_cost,
			ActionPointCommand.Context.Operation.SUB,
			&"play_card"
		)
		append_companion_command(ap_cmd)
	# 目标区域处理（分支内也可合并检查）
	match context_overriding.target_area_type:
		Context.TargetAreaType.CENTER:
			var center_area: AreaCenter = game_state.get_center_area()
			var target_player: Player = game_state.player_manager.get_player_by_id(context_overriding.target_player_id)
			if not (
				RuleGuard.has_valid_area(center_area, _guard_error, "无法获取中央区") and
				RuleGuard.has_valid_player(target_player, _guard_error, "无效的目标玩家ID")
			):
				_fail(_guard_error.text, context_overriding)
				return
			center_area.set_skill_targets([target_player])
			context_overriding.target_area = center_area
		Context.TargetAreaType.PLAYER_DEF:
			var def_area: AreaDefence = game_state.get_defense_area(context_overriding.target_player_id)
			if not RuleGuard.has_valid_area(def_area, _guard_error, "无法获取目标玩家守备区域"):
				_fail(_guard_error.text, context_overriding)
				return
			context_overriding.target_area = def_area
		_:
			_fail("无效的目标区域类型", context_overriding)
			return
	context_overriding.set_id_mode(context_overriding.card_ids)
