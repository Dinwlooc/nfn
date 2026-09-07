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
	if BehaviorCommand.fail_if_null(source_player, context_overriding, "未找到源玩家"): return

	var hand_area: AreaHand = game_state.get_hand_area(source_player.get_id())
	if BehaviorCommand.fail_if_null(hand_area, context_overriding, "无法获取源玩家手牌区域"): return

	var discard_area: AreaDiscard = game_state.get_discard_area()
	if BehaviorCommand.fail_if_null(discard_area, context_overriding, "无法获取弃牌堆区域"): return

	if context_overriding.card_ids.is_empty():
		BehaviorCommand.fail(context_overriding, "无效的卡牌ID数组")
		return

	context_overriding.source_area = hand_area
	context_overriding.target_area = discard_area
	context_overriding.set_id_mode(context_overriding.card_ids)
