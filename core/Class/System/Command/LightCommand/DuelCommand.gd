## 拼点命令 - 重构后
extends BehaviorCommand
class_name DuelCommand

## @context
class Context extends CommandContext:
	enum Phase {
		INIT,
		CALCULATE_POWER,
		EVALUATE_RESULT,
		DONE
	}
	enum Result {
		A_WIN,
		B_WIN,
		TIE
	}

	var card1: Card
	var card2: Card
	var event_name: StringName
	var cached_power1: float = 0.0
	var cached_power2: float = 0.0
	var result: int = Result.TIE
	var point_difference: int = 0

	func set_cards(card_a: Card, card_b: Card, source_event_name: StringName) -> Context:
		card1 = card_a
		card2 = card_b
		event_name = source_event_name
		return self

	func get_primary_modifier_player_ids() -> PackedInt32Array:
		var ids: PackedInt32Array = [player_id]
		if card1 and card2:
			var other_id = card2.get_owner_id() if card1.get_owner_id() == player_id else card1.get_owner_id()
			if other_id != 0 and other_id != player_id:
				ids.append(other_id)
		return ids

	func get_primary_modifier_cards() -> Array[Card]:
		if not card1 or not card2:
			return []
		if card1.get_owner_id() == player_id:
			return [card1, card2]
		else:
			return [card2, card1]

## 信号：拼点完成
signal duel_completed(result: int, point_difference: int)

## @seam_override
## 构造函数：卡牌1、卡牌2、事件名（可选）、发起玩家（默认为卡牌1的持有者或公共玩家）、命令名称、上下文
func _init(
	card1: Card,
	card2: Card,
	event_name: StringName = &"",
	player: Player = card1.player if card1 and card1.player else Player.PUBLIC_PLAYER,
	name_overriding: StringName = &"Duel",
	context_overriding: Context = Context.new()
) -> void:
	context_overriding.set_cards(card1, card2, event_name)
	super._init(player.get_id(), name_overriding, context_overriding)

## @template
func execute(game_state: GameState) -> void:
	var ctx: Context = _context
	match ctx.phase:
		Context.Phase.INIT:
			ctx.phase = Context.Phase.CALCULATE_POWER
			_on_init_phase(game_state, ctx)
		Context.Phase.CALCULATE_POWER:
			ctx.phase = Context.Phase.EVALUATE_RESULT
			_on_calculate_power_phase(game_state, ctx)
		Context.Phase.EVALUATE_RESULT:
			ctx.phase = Context.Phase.DONE
			_on_evaluate_result_phase(game_state, ctx)
		Context.Phase.DONE:
			_on_done_phase(game_state, ctx)

## 静态计算点数
static func do_calculate_power(context: Context, _game_state: GameState) -> void:
	if context.is_virtual:
		return
	context.cached_power1 = context.card1.get_attribute(&"power")
	context.cached_power2 = context.card2.get_attribute(&"power")

## 静态评估结果
static func do_evaluate_result(context: Context, _game_state: GameState) -> void:
	if context.is_virtual:
		return
	context.point_difference = abs(context.cached_power1 - context.cached_power2)
	if context.cached_power1 > context.cached_power2:
		context.result = Context.Result.A_WIN
	elif context.cached_power2 > context.cached_power1:
		context.result = Context.Result.B_WIN
	else:
		context.result = Context.Result.TIE

## @emitter
func _emit_completed(result: int, diff: int) -> void:
	duel_completed.emit(result, diff)

## @hook
func _on_init_phase(_game_state: GameState, _context: Context) -> void:
	pass

## @hook
func _on_calculate_power_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	do_calculate_power(context_overriding as Context, game_state)

## @hook
func _on_evaluate_result_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	do_evaluate_result(context_overriding as Context, game_state)

## @hook
func _on_done_phase(_game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	_emit_completed((context_overriding as Context).result, (context_overriding as Context).point_difference)
	complete()
