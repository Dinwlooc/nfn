## 将弃牌区所有牌移入抽牌区并随机排列。
## 用于抽牌区不足时补充牌库，或闲置期自动维护。
extends CardMoveCommand
class_name ShuffleCommand

## @context @deep_inherit
class Context extends CardMoveCommand.Context:
	pass

## @seam_override
func _init(player: Player = Player.PUBLIC_PLAYER, name_overriding: StringName = &"Shuffle", context_overriding: Context = Context.new()) -> void:
	super._init(player, name_overriding, context_overriding)

## @hook @seam_override
func _on_init_phase(game_state: GameState, context_overriding: CardMoveCommand.Context = _context as Context) -> void:
	if context_overriding is not Context:
		BehaviorCommand.fail(context_overriding, "上下文类型错误")
		return
	var discard: AreaDiscard = game_state.get_discard_area()
	if BehaviorCommand.fail_if_null(discard, context_overriding, "无法获取弃牌区"): return

	var drawing: AreaDrawing = game_state.get_drawing_area()
	if BehaviorCommand.fail_if_null(drawing, context_overriding, "无法获取抽牌区"): return

	var ids: PackedInt32Array = discard.get_card_ids()
	if ids.is_empty():
		BehaviorCommand.fail(context_overriding, "弃牌区为空，无需洗牌")
		return

	context_overriding.set_id_mode(ids)
	context_overriding.set_source_area(discard)
	context_overriding.set_target_area(drawing)

## @hook @seam_override
func _on_move_in_phase(game_state: GameState, context_overriding: CardMoveCommand.Context = _context as Context) -> void:
	var shuffle_context := context_overriding as Context
	if not shuffle_context:
		BehaviorCommand.fail(context_overriding, "上下文类型错误")
		return
	super._on_move_in_phase(game_state, shuffle_context)
	var drawing: AreaDrawing = game_state.get_drawing_area()
	if drawing:
		drawing.shuffle_card_pool()
