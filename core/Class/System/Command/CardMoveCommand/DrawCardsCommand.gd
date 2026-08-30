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

func _init(player: Player, draw_count: int, name_overriding: StringName = &"DrawCards", context_overriding: Context = Context.new()) -> void:
	super._init(player, name_overriding, context_overriding)
	_context.set_draw_count(draw_count)

func _on_init_phase(game_state: GameState) -> void:
	var draw_context := _context as Context
	if not draw_context:
		push_error("DrawCardsCommand: 上下文类型错误")
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	var source_player: Player = _context.get_source_player()
	if not source_player:
		push_error("DrawCardsCommand: 源玩家无效")
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	# 获取牌堆区域（公共区）
	var drawing_area: AreaDrawing = game_state.get_drawing_area()
	if not drawing_area:
		push_error("DrawCardsCommand: 无法获取牌堆区域")
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	_context.source_area = drawing_area
	# 获取目标手牌区域
	var hand_area: AreaHand = game_state.get_hand_area(source_player.get_id())
	if not hand_area:
		push_error("DrawCardsCommand: 无法获取玩家手牌区域")
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	_context.target_area = hand_area
	# 抽牌不足时伴生洗牌命令（此时牌堆已确认非空，但可能数量不足）
	if drawing_area.card_count() < draw_context.draw_count:
		append_companion_command(ShuffleCommand.new(source_player))
	var actual: int = draw_context.get_actual_draw_count(drawing_area)
	if actual <= 0:
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	draw_context.set_top_mode(actual)
