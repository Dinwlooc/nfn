extends CardMoveCommand
class_name DrawCardsCommand

## 抽牌命令上下文类
class Context extends CardMoveCommand.Context:
	var draw_count: int = 0
	## 设置抽牌数量
	func set_draw_count(count: int) -> void:
		draw_count = count
	## 获取实际的抽牌数量（考虑源区域的卡牌数量限制）
	func get_actual_draw_count(source_area: Area) -> int:
		if not source_area:
			return 0
		return min(draw_count, source_area.card_count())
## 抽牌命令
func _init(init_player_index: int, draw_count: int, name_overriding:StringName = &"DrawCards",context_overriding:Context = Context.new()) -> void:
	super._init(init_player_index,name_overriding,context_overriding)
	_context.set_draw_count(draw_count)
## 覆盖父类的初始化阶段方法
func _on_init_phase(game_state: GameState) -> void:
	var draw_context := _context as Context
	if not draw_context:
		push_error("DrawCardsCommand: 上下文类型错误")
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	_context.source_area = game_state.area_drawing
	_context.target_area = game_state.player_manager.get_player_by_seat(_context.player_id).area_hand
	var actual_draw_count = draw_context.get_actual_draw_count(_context.source_area)
	if actual_draw_count <= 0:
		_context.phase = CardMoveCommand.Context.Phase.DONE
		return
	draw_context.set_top_mode(actual_draw_count)
	_context.phase = CardMoveCommand.Context.Phase.MOVE_OUT
