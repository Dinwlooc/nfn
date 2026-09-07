extends BehaviorCommand
class_name BattleCommand

## @context
class Context extends CommandContext:
	enum Phase {
		INIT,
		PRE_DUEL,
		CREATE_DUEL,
		PROCESS_RESULT,
		DONE
	}
	var defensive_area: AreaDefence
	var top_card: Card
	var second_card: Card
	var duel_result: int = DuelCommand.Context.Result.TIE
	var duel_diff: int = 0

	func set_battle_params(area: AreaDefence, top: Card, second: Card) -> Context:
		defensive_area = area
		top_card = top
		second_card = second
		return self

	func get_primary_modifier_cards() -> Array[Card]:
		return [top_card, second_card]

const BASE_MORALE_GAIN: int = 1
const MORALE_BONUS_WIN: int = 1

## @seam_override
func _init(
	area: AreaDefence,
	top: Card,
	second: Card,
	name_overriding: StringName = &"Battle",
	context_overriding: Context = Context.new()
) -> void:
	context_overriding.set_battle_params(area, top, second)
	super._init(top.get_owner_id(), name_overriding, context_overriding)

## @template
func execute(game_state: GameState) -> void:
	if _context.is_cancelled:
		complete()
		return
	var ctx: Context = _context
	match ctx.phase:
		Context.Phase.INIT:
			ctx.phase = Context.Phase.PRE_DUEL
			_on_init_phase(game_state, ctx)
		Context.Phase.PRE_DUEL:
			ctx.phase = Context.Phase.CREATE_DUEL
			_on_pre_duel_phase(game_state, ctx)
		Context.Phase.CREATE_DUEL:
			ctx.phase = Context.Phase.PROCESS_RESULT
			_on_create_duel_phase(game_state, ctx)
		Context.Phase.PROCESS_RESULT:
			ctx.phase = Context.Phase.DONE
			_on_process_result_phase(game_state, ctx)
		Context.Phase.DONE:
			_on_done_phase(game_state, ctx)

## 静态初始化：检查双方是否同属一个玩家，若相同则直接完成
static func do_init(context: Context, _game_state: GameState) -> void:
	if context.is_virtual:
		context.phase = Context.Phase.DONE
		return
	if context.second_card.player == context.top_card.player:
		context.phase = Context.Phase.DONE

## 静态预拼点阶段（专供修饰器触发）
static func do_pre_duel(_context: Context, _game_state: GameState) -> void:
	# 无操作，仅为修饰器预留
	pass

## 静态创建拼点命令并连接信号
static func do_create_duel(context: Context, _game_state: GameState, command_owner: BattleCommand) -> void:
	if context.is_virtual:
		context.phase = Context.Phase.DONE
		return
	var duel_command := DuelCommand.new(context.top_card, context.second_card, &"BattleCommand")
	duel_command.duel_completed.connect(command_owner._on_duel_completed)
	command_owner.append_companion_command(duel_command)

## 静态处理结果：计算双方战意并创建 MoraleCommand
static func do_process_result(context: Context, _game_state: GameState, command_owner: BattleCommand) -> void:
	if context.is_virtual:
		context.phase = Context.Phase.DONE
		return
	var player_top: Player = context.top_card.player
	var player_second: Player = context.second_card.player
	if not player_top or not player_second:
		context.phase = Context.Phase.DONE
		return

	var attack_delta_top: int = 0
	var defense_delta_top: int = 0
	var attack_delta_second: int = 0
	var defense_delta_second: int = 0

	if context.top_card.type == GlobalConstants.DefaultCard.ATTACK:
		attack_delta_top = BASE_MORALE_GAIN
	else:
		defense_delta_top = BASE_MORALE_GAIN

	if context.second_card.type == GlobalConstants.DefaultCard.ATTACK:
		attack_delta_second = BASE_MORALE_GAIN
	else:
		defense_delta_second = BASE_MORALE_GAIN

	match context.duel_result:
		DuelCommand.Context.Result.A_WIN:
			if context.top_card.type == GlobalConstants.DefaultCard.ATTACK:
				attack_delta_top += MORALE_BONUS_WIN
			else:
				defense_delta_top += MORALE_BONUS_WIN
		DuelCommand.Context.Result.B_WIN:
			if context.second_card.type == GlobalConstants.DefaultCard.ATTACK:
				attack_delta_second += MORALE_BONUS_WIN
			else:
				defense_delta_second += MORALE_BONUS_WIN
		_:
			pass

	if attack_delta_top != 0 or defense_delta_top != 0:
		var morale_cmd := MoraleCommand.new(player_top, attack_delta_top, defense_delta_top, player_top.get_id(), &"BattleCommand")
		command_owner.append_companion_command(morale_cmd)
	if attack_delta_second != 0 or defense_delta_second != 0:
		var morale_cmd := MoraleCommand.new(player_second, attack_delta_second, defense_delta_second, player_second.get_id(), &"BattleCommand")
		command_owner.append_companion_command(morale_cmd)

	GlobalConsole._print([
		"斗牌结束，玩家", player_top.get_id(), "战意：攻击", player_top.morale_attack, "防御", player_top.morale_defense,
		"，玩家", player_second.get_id(), "战意：攻击", player_second.morale_attack, "防御", player_second.morale_defense
	])

## @hook
func _on_init_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	do_init(context_overriding as Context, game_state)

## @hook
func _on_pre_duel_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	do_pre_duel(context_overriding as Context, game_state)

## @hook
func _on_create_duel_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	do_create_duel(context_overriding as Context, game_state, self)

## @hook
func _on_process_result_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	do_process_result(context_overriding as Context, game_state, self)

## @hook
func _on_done_phase(_game_state: GameState, _context: CommandContext = _context as Context) -> void:
	complete()

## @signal_listener
func _on_duel_completed(result: int, diff: int) -> void:
	var ctx := _context as Context
	if not ctx:
		return
	ctx.duel_result = result
	ctx.duel_diff = diff
