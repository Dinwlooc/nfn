extends CardMoveCommand
class_name DrawCardsCommand

## 抽牌命令上下文类
## @context @deep_inherit
class Context extends CardMoveCommand.Context:
	var draw_count: int = 0
	func set_draw_count(count: int) -> void:
		draw_count = count
	func get_actual_draw_count(source_area: Area) -> int:
		if not source_area:
			return 0
		return min(draw_count, source_area.card_count())

## @seam_override
func _init(player: Player, draw_count: int, name_overriding: StringName = &"DrawCards", context_overriding: Context = Context.new()) -> void:
	super._init(player, name_overriding, context_overriding)
	_context.set_draw_count(draw_count)

## @hook @seam_override
func _on_init_phase(game_state: GameState, context_overriding: CardMoveCommand.Context = _context as Context) -> void:
	if context_overriding is not Context:
		_fail("上下文类型错误", context_overriding)
		return
	var err := RuleGuard.ErrorMessage.new()
	var source_player: Player = context_overriding.get_source_player()
	var drawing_area: AreaDrawing = game_state.get_drawing_area()
	if not (
		RuleGuard.has_valid_player(source_player, err, "源玩家无效") and
		RuleGuard.has_valid_area(drawing_area, err, "无法获取牌堆区域") and
		RuleGuard.has_valid_area(game_state.get_hand_area(source_player.get_id()), err, "无法获取玩家手牌区域")
	):
		_fail(err.text, context_overriding)
		return
	var hand_area: AreaHand = game_state.get_hand_area(source_player.get_id())
	context_overriding.source_area = drawing_area
	context_overriding.target_area = hand_area
	if drawing_area.card_count() < context_overriding.draw_count:
		append_companion_command(ShuffleCommand.new(source_player))
	var actual: int = context_overriding.get_actual_draw_count(drawing_area)
	if actual <= 0:
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	context_overriding.set_top_mode(actual)
