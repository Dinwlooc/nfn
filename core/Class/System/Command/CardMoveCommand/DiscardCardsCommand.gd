## 弃牌命令
extends CardMoveCommand
class_name DiscardCardsCommand

class Context extends CardMoveCommand.Context:
	var card_ids: PackedInt32Array = PackedInt32Array()
	func set_card_ids(ids: PackedInt32Array) -> void:
		card_ids = ids
	func are_card_ids_valid() -> bool:
		return not card_ids.is_empty()

## 静态初始化。允许空弃牌。行为设计如此。
static func init(context: Context, game_state: GameState) -> void:
	var source_player: Player = context.get_source_player()
	if BehaviorCommand.fail_if_null(source_player, context, "未找到源玩家"): return
	var hand_area: AreaHand = game_state.get_hand_area(source_player.get_id())
	if BehaviorCommand.fail_if_null(hand_area, context, "无法获取源玩家手牌区域"): return
	var discard_area: AreaDiscard = game_state.get_discard_area()
	if BehaviorCommand.fail_if_null(discard_area, context, "无法获取弃牌堆区域"): return
	context.source_area = hand_area
	context.target_area = discard_area
	context.set_id_mode(context.card_ids)

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

## @hook
func _on_init_phase(game_state: GameState, context_overriding: CardMoveCommand.Context = _context as Context) -> void:
	DiscardCardsCommand.init(context_overriding, game_state)
