## 拼点命令 - 重构后
extends BehaviorCommand
class_name DuelCommand

## @context
class Context extends CommandContext:
	## 拼点命令的三阶段状态
	enum Phase {
		INIT,
		EVALUATE_RESULT,
		DONE
	}
	## 拼点结果
	enum Result {
		A_WIN,
		B_WIN,
		TIE
	}

	## 参与拼点的第一张卡牌
	var card1: Card
	## 参与拼点的第二张卡牌
	var card2: Card
	## 拼点事件名
	var event_name: StringName
	## 准备阶段缓存的第一张卡牌威力
	var cached_power1: float = 0.0
	## 准备阶段缓存的第二张卡牌威力
	var cached_power2: float = 0.0
	## 拼点结果（Result 枚举）
	var result: int = Result.TIE
	## 双方点数差（绝对值）
	var point_difference: int = 0

	## 链式设置两张拼点卡牌与事件名
	func set_cards(card_a: Card, card_b: Card, source_event_name: StringName) -> Context:
		card1 = card_a
		card2 = card_b
		event_name = source_event_name
		return self

	## 两张拼点卡的持有者都参与修饰
	## @hook @override
	func get_primary_modifier_players() -> Array[Player]:
		var players: Array[Player] = []
		if card1 and card1.player:
			players.append(card1.player)
		if card2 and card2.player and not players.has(card2.player):
			players.append(card2.player)
		return players

	## 按发起方视角返回两张卡的修饰顺序
	## @hook @override
	func get_primary_modifier_cards() -> Array[Card]:
		if not card1 or not card2:
			return []
		if card1.get_owner_id() == player_id:
			return [card1, card2]
		return [card2, card1]

## 信号：拼点完成
## @emitter
signal duel_completed(result: int, point_difference: int)

## @internal @seam_override
func _init(
	card1: Card,
	card2: Card,
	event_name: StringName = &"",
	player: Player = card1.player if card1 and card1.player else Player.PUBLIC_PLAYER,
	name_overriding: StringName = &"Duel",
	context_overriding: Context = Context.new()
) -> void:
	super._init(player.get_id(), name_overriding, context_overriding)
	_context.set_cards(card1, card2, event_name)

## @facade @template
func execute(game_state: GameState) -> void:
	var ctx: Context = _context as Context
	match ctx.phase:
		Context.Phase.INIT:
			ctx.phase = Context.Phase.EVALUATE_RESULT
			_on_init_phase(game_state, ctx)
		Context.Phase.EVALUATE_RESULT:
			ctx.phase = Context.Phase.DONE
			_on_evaluate_result_phase(game_state, ctx)
		Context.Phase.DONE:
			_on_done_phase(game_state, ctx)

## @hook @operation(do_calculate_power)
func _on_init_phase(game_state: GameState, context_overriding: Context = _context as Context) -> void:
	do_calculate_power(context_overriding, game_state)

## @hook @operation(do_evaluate_result)
func _on_evaluate_result_phase(game_state: GameState, context_overriding: Context = _context as Context) -> void:
	do_evaluate_result(context_overriding, game_state)

## @hook @delegates(complete)
func _on_done_phase(_game_state: GameState, context_overriding: Context = _context as Context) -> void:
	if not context_overriding.is_virtual:
		_emit_completed(context_overriding.result, context_overriding.point_difference)
	complete()

## @emitter
func _emit_completed(result: int, diff: int) -> void:
	duel_completed.emit(result, diff)

## 静态计算点数
static func do_calculate_power(context: Context, _game_state: GameState) -> void:
	context.cached_power1 = context.card1.get_attribute(&"power")
	context.cached_power2 = context.card2.get_attribute(&"power")

## 静态评估结果
static func do_evaluate_result(context: Context, _game_state: GameState) -> void:
	context.point_difference = abs(context.cached_power1 - context.cached_power2)
	if context.cached_power1 > context.cached_power2:
		context.result = Context.Result.A_WIN
		return
	if context.cached_power2 > context.cached_power1:
		context.result = Context.Result.B_WIN
		return
	context.result = Context.Result.TIE
