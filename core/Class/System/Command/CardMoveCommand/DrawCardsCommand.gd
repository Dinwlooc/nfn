extends CardMoveCommand
class_name DrawCardsCommand

## 抽牌命令上下文类
class Context extends CardMoveCommand.Context:
	var draw_count: int = 0
	func set_draw_count(count: int) -> void:
		draw_count = count
	func get_actual_draw_count(source_area: Area) -> int:
		if not source_area:
			return 0
		return min(draw_count, source_area.card_count())

func _init(init_player_index: int, draw_count: int, name_overriding: StringName = &"DrawCards", context_overriding: Context = Context.new()) -> void:
	super._init(init_player_index, name_overriding, context_overriding)
	_context.set_draw_count(draw_count)

func _on_init_phase(game_state: GameState) -> void:
	var draw_context := _context as Context
	if not draw_context:
		push_error("DrawCardsCommand: 上下文类型错误")
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	_context.source_area = game_state.get_drawing_area()
	_context.target_area = game_state.get_hand_area(_context.player_id)
	# 抽牌不足时伴生洗牌命令（仅发射，不改变后续流程）
	if _context.source_area.card_count() < draw_context.draw_count:
		append_companion_command(ShuffleCommand.new())
	var actual: int = draw_context.get_actual_draw_count(_context.source_area)
	if actual <= 0:
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	draw_context.set_top_mode(actual)
	_context.phase = CardMoveCommand.Context.Phase.MOVE_OUT
