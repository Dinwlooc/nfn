## 将弃牌区所有牌移入抽牌区并随机排列。
## 用于抽牌区不足时补充牌库，或闲置期自动维护。
extends CardMoveCommand
class_name ShuffleCommand

func _init(player_id: int = 1, name_overriding: StringName = &"Shuffle", context_overriding: CardMoveCommand.Context = CardMoveCommand.Context.new()) -> void:
	super._init(player_id, name_overriding, context_overriding)

func _on_init_phase(game_state: GameState) -> void:
	var discard: AreaDiscard = game_state.get_discard_area()
	var drawing: AreaDrawing = game_state.get_drawing_area()
	if not discard or not drawing:
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	var ids: PackedInt32Array = discard.get_card_ids()
	if ids.is_empty():
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	_context.set_id_mode(ids)
	_context.set_source_area(discard)
	_context.set_target_area(drawing)
	_context.phase = CardMoveCommand.Context.Phase.MOVE_OUT

func _on_move_in_phase(game_state: GameState) -> void:
	super._on_move_in_phase(game_state)
	var drawing: AreaDrawing = game_state.get_drawing_area()
	if drawing:
		drawing.shuffle_card_pool()
