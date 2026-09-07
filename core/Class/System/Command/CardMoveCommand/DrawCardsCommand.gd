extends CardMoveCommand
class_name DrawCardsCommand

class Context extends CardMoveCommand.Context:
	var draw_count: int = 0
	func set_draw_count(count: int) -> void:
		draw_count = count
	func get_actual_draw_count(source_area: Area) -> int:
		if not source_area:
			return 0
		return min(draw_count, source_area.card_count())

## 静态初始化：校验并设置源/目标区域，计算实际抽牌数并设置模式
static func init(context: Context, game_state: GameState) -> void:
	var source_player: Player = context.get_source_player()
	if BehaviorCommand.fail_if_null(source_player, context, "源玩家无效"): return

	var drawing_area: AreaDrawing = game_state.get_drawing_area()
	if BehaviorCommand.fail_if_null(drawing_area, context, "无法获取牌堆区域"): return

	var hand_area: AreaHand = game_state.get_hand_area(source_player.get_id())
	if BehaviorCommand.fail_if_null(hand_area, context, "无法获取玩家手牌区域"): return

	context.source_area = drawing_area
	context.target_area = hand_area

	var actual: int = context.get_actual_draw_count(drawing_area)
	context.set_top_mode(actual)

## 构建洗牌伴生命令（当牌堆不足时）
static func build_shuffle_companion(context: Context, game_state: GameState) -> ShuffleCommand:
	var drawing_area: AreaDrawing = game_state.get_drawing_area()
	if not drawing_area:
		return null
	if drawing_area.card_count() >= context.draw_count:
		return null
	# 需传入源玩家（洗牌命令的发起者）
	var source_player: Player = context.get_source_player()
	if not source_player:
		return null
	return ShuffleCommand.new(source_player)

## @seam_override
func _init(player: Player, draw_count: int, name_overriding: StringName = &"DrawCards", context_overriding: Context = Context.new()) -> void:
	super._init(player, name_overriding, context_overriding)
	_context.set_draw_count(draw_count)

## @hook
func _on_init_phase(game_state: GameState, context_overriding: CardMoveCommand.Context = _context as Context) -> void:
	if context_overriding is not Context:
		BehaviorCommand.fail(context_overriding, "上下文类型错误")
		return
	DrawCardsCommand.init(context_overriding, game_state)
	var shuffle_cmd := DrawCardsCommand.build_shuffle_companion(context_overriding, game_state)
	if not shuffle_cmd:
		return
	append_companion_command(shuffle_cmd)
