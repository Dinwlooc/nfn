## 摧毁命令
extends CardMoveCommand
class_name DestroyCardsCommand

class Context extends CardMoveCommand.Context:
	var source_card: Card = null
	var target_card_id: int = 0
	var target_defense_area: AreaDefence = null

	func set_source_card(card: Card) -> void:
		source_card = card
	func set_target_card_id(id: int) -> void:
		target_card_id = id
	func set_target_defense_area(area: AreaDefence) -> void:
		target_defense_area = area

## 静态初始化
static func init(context: Context, game_state: GameState) -> void:
	if BehaviorCommand.fail_if_null(context.target_defense_area, context, "目标守区未设置"):
		return
	var cards: Array[Card] = context.target_defense_area.get_cards_by_ids(PackedInt32Array([context.target_card_id]))
	if cards.is_empty():
		GlobalConsole._print(["[%s] 目标卡牌不在目标守区，取消摧毁。" % context.command_name])
		context.phase = CardMoveCommand.Context.Phase.DONE
		return
	var discard_area: AreaDiscard = game_state.get_discard_area()
	if BehaviorCommand.fail_if_null(discard_area, context, "无法获取弃牌区"):
		return
	context.source_area = context.target_defense_area
	context.target_area = discard_area
	context.set_id_mode(PackedInt32Array([context.target_card_id]))

## @seam_override
func _init(
	target_defense_area: AreaDefence,
	target_card_id: int,
	source_player: Player = Player.PUBLIC_PLAYER,
	source_card: Card = null,
	name_overriding: StringName = &"DestroyCards",
	context_overriding: Context = Context.new()
) -> void:
	super._init(source_player, name_overriding, context_overriding)
	_context.set_target_defense_area(target_defense_area)
	_context.set_target_card_id(target_card_id)
	_context.set_source_card(source_card)
	_context.set_event_type(RenderRequest.ItemSet.EventType.DEATH)

## @hook
func _on_init_phase(game_state: GameState, context_overriding: CardMoveCommand.Context = _context as Context) -> void:
	DestroyCardsCommand.init(context_overriding, game_state)
