## 洗牌命令
extends CardMoveCommand
class_name ShuffleCommand

class Context extends CardMoveCommand.Context:
	pass

## 静态初始化。弃牌区为空时直接完成。行为设计如此。
static func init(context: Context, game_state: GameState) -> void:
	var discard: AreaDiscard = game_state.get_discard_area()
	if BehaviorCommand.fail_if_null(discard, context, "无法获取弃牌区"): return
	var drawing: AreaDrawing = game_state.get_drawing_area()
	if BehaviorCommand.fail_if_null(drawing, context, "无法获取抽牌区"): return
	var ids: PackedInt32Array = discard.get_card_ids()
	if ids.is_empty():
		context.phase = CardMoveCommand.Context.Phase.DONE
		return
	context.set_id_mode(ids)
	context.set_source_area(discard)
	context.set_target_area(drawing)

## @seam_override
func _init(player: Player = Player.PUBLIC_PLAYER, name_overriding: StringName = &"Shuffle", context_overriding: Context = Context.new()) -> void:
	super._init(player, name_overriding, context_overriding)
## @hook
func _on_init_phase(game_state: GameState, context_overriding: CardMoveCommand.Context = _context as Context) -> void:
	if context_overriding is not Context:
		BehaviorCommand.fail(context_overriding, "上下文类型错误")
		return
	ShuffleCommand.init(context_overriding, game_state)
## @hook
func _on_move_in_phase(game_state: GameState, context_overriding: CardMoveCommand.Context = _context as Context) -> void:
	if context_overriding is not Context:
		BehaviorCommand.fail(context_overriding, "上下文类型错误")
		return
	super._on_move_in_phase(game_state, context_overriding)
	var drawing: AreaDrawing = game_state.get_drawing_area()
	if drawing:
		drawing.shuffle_card_pool()
