## 弃牌命令：将手牌中指定卡牌移至弃牌堆。
extends CardMoveCommand
class_name DiscardCardsCommand

## 弃牌命令上下文。
## @context @deep_inherit
class Context extends CardMoveCommand.Context:
	var card_ids: PackedInt32Array = PackedInt32Array()

	func set_card_ids(ids: PackedInt32Array) -> void:
		card_ids = ids

	func are_card_ids_valid() -> bool:
		return not card_ids.is_empty()
## @seam_override
func _init(
	player: Player,
	card_ids: PackedInt32Array,
	name_overriding: StringName = &"DiscardCards",
	context_overriding: Context = Context.new()
) -> void:
	super._init(player, name_overriding, context_overriding)
	_context.set_card_ids(card_ids)
	_context.set_event_type(RenderRequest.ItemSet.EventType.DISCARD)
## @hook @seam_override
func _on_init_phase(game_state: GameState, context_overriding: CardMoveCommand.Context = _context as Context) -> void:
	var source_player: Player = context_overriding.get_source_player()
	if not (
		RuleGuard.has_valid_card_ids(context_overriding.card_ids, _guard_error, "无效的卡牌ID数组") and
		RuleGuard.has_valid_player(source_player, _guard_error, "未找到源玩家") and
		RuleGuard.has_valid_area(game_state.get_hand_area(source_player.get_id()), _guard_error, "无法获取源玩家手牌区域") and
		RuleGuard.has_valid_area(game_state.get_discard_area(), _guard_error, "无法获取弃牌堆区域")
	):
		_fail(_guard_error.text, context_overriding)
		return
	var hand_area: AreaHand = game_state.get_hand_area(source_player.get_id())
	var discard_area: AreaDiscard = game_state.get_discard_area()
	context_overriding.source_area = hand_area
	context_overriding.target_area = discard_area
	context_overriding.set_id_mode(context_overriding.card_ids)
