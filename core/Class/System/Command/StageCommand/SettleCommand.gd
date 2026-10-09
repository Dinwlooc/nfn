extends BehaviorCommand
class_name SettleCommand

## @context
class Context extends CommandContext:
	enum Phase {
		PREPARE,
		ATTACK_JUDGE,
		DAMAGE,
		EFFECT,
		CLEAR,
		DONE
	}
	var defensive_area: AreaDefence = null
	var attacker: Player = null
	var settle_card: Card = null
	var oppose_card: Card = null
	var is_unilateral: bool = false
	var duel_result: int = DuelCommand.Context.Result.TIE
	var duel_diff: int = 0
	var settle_result: RuleSettle.Result = null

	func get_settle_card() -> Card:
		return settle_card

	func get_oppose_card() -> Card:
		return oppose_card

	func set_defensive_area(area: AreaDefence) -> Context:
		if phase != Phase.PREPARE:
			push_error("只能在预备阶段设置守区")
			return self
		defensive_area = area
		return self

	func set_attacker(player: Player) -> Context:
		if phase != Phase.PREPARE:
			push_error("只能在预备阶段设置攻击者")
			return self
		attacker = player
		return self

	func set_settle_card(card: Card) -> Context:
		if phase != Phase.PREPARE and phase != Phase.ATTACK_JUDGE:
			push_error("只能在预备阶段或攻击判断阶段重设结算牌")
			return self
		settle_card = card
		return self

	func set_oppose_card(card: Card) -> Context:
		if phase != Phase.PREPARE and phase != Phase.ATTACK_JUDGE:
			push_error("只能在预备阶段或攻击判断阶段重设对抗牌")
			return self
		oppose_card = card
		return self

	func get_primary_modifier_players() -> Array[Player]:
		var players: Array[Player] = []
		if settle_card and settle_card.player:
			players.append(settle_card.player)
		if oppose_card and oppose_card.player and not players.has(oppose_card.player):
			players.append(oppose_card.player)
		return players

	func get_primary_modifier_cards() -> Array[Card]:
		var cards: Array[Card] = []
		if settle_card:
			cards.append(settle_card)
		if oppose_card:
			cards.append(oppose_card)
		return cards

	## @override
	func complete() -> void:
		phase = Phase.DONE
		super.complete()

## @internal @seam_override
func _init(
	player_id: int,
	target_defensive_area: AreaDefence,
	attacker: Player,
	name_overriding: StringName = &"Settle",
	context_overriding: Context = Context.new()
) -> void:
	super._init(player_id, name_overriding, context_overriding)
	context_overriding.set_defensive_area(target_defensive_area).set_attacker(attacker)

## @facade @template
func execute(game_state: GameState) -> void:
	if _context.is_cancelled:
		complete()
		return
	var ctx: Context = _context as Context
	match ctx.phase:
		Context.Phase.PREPARE:
			ctx.phase = Context.Phase.ATTACK_JUDGE
			_on_prepare_phase(game_state, ctx)
		Context.Phase.ATTACK_JUDGE:
			ctx.phase = Context.Phase.DAMAGE
			_on_attack_judge_phase(game_state, ctx)
		Context.Phase.DAMAGE:
			ctx.phase = Context.Phase.EFFECT
			_on_damage_phase(game_state, ctx)
		Context.Phase.EFFECT:
			ctx.phase = Context.Phase.CLEAR
			_on_effect_phase(game_state, ctx)
		Context.Phase.CLEAR:
			ctx.phase = Context.Phase.DONE
			_on_clear_phase(game_state, ctx)
		Context.Phase.DONE:
			_on_done_phase(game_state, ctx)

## @hook @operation(do_prepare) @delegates(_listen_card_area_changed)
func _on_prepare_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	var ctx: Context = context_overriding as Context
	do_prepare(ctx, game_state)
	if ctx.settle_card:
		_listen_card_area_changed(ctx.settle_card)
	if ctx.oppose_card:
		_listen_card_area_changed(ctx.oppose_card)

## @hook @operation(do_attack_judge) @delegates(_listen_duel_completed, append_companion_command)
func _on_attack_judge_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	var ctx: Context = context_overriding as Context
	var duel: DuelCommand = do_attack_judge(ctx, game_state)
	if not duel:
		return
	_listen_duel_completed(duel)
	append_companion_command(duel)

## @hook @operation(do_damage) @delegates(append_companion_command)
func _on_damage_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	var ctx: Context = context_overriding as Context
	var commands: Array[BehaviorCommand] = do_damage(ctx, game_state)
	for cmd in commands:
		append_companion_command(cmd)

## 纯修饰位点。设计如此。
## @hook
func _on_effect_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	pass

## @hook @operation(do_clear) @delegates(append_companion_command)
func _on_clear_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	var ctx: Context = context_overriding as Context
	var transfer_cmd: CardTransferCommand = do_clear(ctx, game_state)
	if not transfer_cmd:
		return
	append_companion_command(transfer_cmd)

## @hook @delegates(complete)
func _on_done_phase(_game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	complete()

## @signal_once
func _listen_duel_completed(duel: DuelCommand) -> void:
	duel.duel_completed.connect(_on_opponent_duel_completed, CONNECT_ONE_SHOT)

## @signal_once
func _on_opponent_duel_completed(result: int, diff: int) -> void:
	var ctx: Context = _context as Context
	if not ctx:
		return
	ctx.duel_result = result
	ctx.duel_diff = diff
	# 仅当 attacker 不是守区玩家且非单边时进行衰减计算
	if ctx.attacker == ctx.defensive_area.player or ctx.is_unilateral:
		return
	var settle_card: Card = ctx.settle_card
	if not settle_card:
		return
	var rules: Dictionary = RuleSettle._get_merged_rules(settle_card, {})
	var health_mode: int = rules.get(RuleSettle.Validator.LIFE_DAMAGE_MODE, RuleSettle.DamageMode.NONE)
	var mental_mode: int = rules.get(RuleSettle.Validator.MENTAL_DAMAGE_MODE, RuleSettle.DamageMode.NONE)
	var oppose_power: int = ctx.oppose_card.get_attribute(&"power") if ctx.oppose_card else 0
	ctx.settle_result = RuleSettle.apply_decay(
		ctx.settle_result,
		ctx.is_unilateral,
		result,
		diff,
		oppose_power,
		health_mode,
		mental_mode
	)

## @signal_once
func _listen_card_area_changed(card: Card) -> void:
	card.area_changed.connect(_on_card_area_changed, CONNECT_ONE_SHOT)

## @signal_once
func _on_card_area_changed(card: Card) -> void:
	var ctx: Context = _context as Context
	if not ctx:
		return
	if card == ctx.settle_card:
		ctx.settle_card = null
	elif card == ctx.oppose_card:
		ctx.oppose_card = null

## 静态准备阶段：初始化守区，获取结算牌和对抗牌
static func do_prepare(context: Context, game_state: GameState) -> void:
	if context.is_virtual:
		context.phase = Context.Phase.DONE
		return
	if not context.defensive_area:
		BehaviorCommand.fail(context, "防御区域未设置")
		return
	context.defensive_area.settle_defense_area()
	context.settle_card = context.defensive_area.get_top_card()
	if context.defensive_area.get_second_card() and context.defensive_area.get_second_card().player != context.settle_card.player:
		context.oppose_card = context.defensive_area.get_second_card()
	context.is_unilateral = (context.oppose_card == null)

## 静态攻击判断阶段：计算初始结算信息，需要时返回拼点命令
static func do_attack_judge(context: Context, game_state: GameState) -> DuelCommand:
	if context.is_virtual:
		context.phase = Context.Phase.DONE
		return null
	if not context.settle_card:
		context.phase = Context.Phase.DONE
		return null
	context.settle_result = RuleSettle.get_initial_info(
		context.settle_card, context.oppose_card, context.is_unilateral,
		context.attacker, context.defensive_area.player, {}
	)
	if not context.is_unilateral and context.oppose_card.player != context.settle_card.player:
		return DuelCommand.new(context.settle_card, context.oppose_card, &"Settle")
	return null

## 静态伤害阶段：应用伤害和战意，返回需要伴生的命令
static func do_damage(context: Context, game_state: GameState) -> Array[BehaviorCommand]:
	var commands: Array[BehaviorCommand] = []
	if context.is_virtual:
		context.phase = Context.Phase.DONE
		return commands
	if not context.settle_card or not context.settle_result:
		context.phase = Context.Phase.DONE
		return commands
	var rules: Dictionary[StringName, Variant] = RuleSettle._get_merged_rules(context.settle_card, {})
	var mask: int = rules.get(RuleSettle.Validator.COMBAT_WILL_MODE, 0)
	var grants: Array[RuleSettle.CombatWillGrant] = RuleSettle.generate_combat_will_grants(
		context.settle_card,
		context.oppose_card,
		context.duel_result,
		context.duel_diff,
		context.is_unilateral,
		mask,
		context.attacker,
		context.defensive_area.player
	)
	commands.append_array(_build_combat_will_commands(grants, context))
	if not context.settle_result.target:
		return commands
	var damage_cmd: DamageCommand = DamageCommand.new(
		context.settle_result.target,
		context.settle_result.health_damage_value,
		context.settle_result.mental_damage_value,
		DamageCommand.SourceMechanism.GENERAL,
		context.settle_card.get_owner_id()
	)
	commands.append(damage_cmd)
	return commands

## 静态清理阶段：返回将防御区所有牌移到弃牌堆的命令
static func do_clear(context: Context, game_state: GameState) -> CardTransferCommand:
	if context.is_virtual:
		context.phase = Context.Phase.DONE
		return null
	return CardTransferCommand.new(
		game_state.get_player_by_id(context.player_id),
		context.defensive_area,
		game_state.get_discard_area(),
		CardTransferCommand.Context.MoveOutMode.TOP,
		context.defensive_area.card_count()
	)

## 辅助静态方法：将战意授予转换为 MoraleCommand 列表
static func _build_combat_will_commands(
	grants: Array[RuleSettle.CombatWillGrant],
	context: Context
) -> Array[BehaviorCommand]:
	var commands: Array[BehaviorCommand] = []
	var source_id: int = context.settle_card.get_owner_id() if context.settle_card else 0
	for grant in grants:
		var player: Player = grant.target_player
		if not player:
			continue
		var total_value: int = grant.base_value + grant.extra_value
		if total_value <= 0:
			continue
		var attack_delta: int = total_value if not grant.is_defense else 0
		var defense_delta: int = total_value if grant.is_defense else 0
		var morale_cmd: MoraleCommand = MoraleCommand.new(
			player,
			attack_delta,
			defense_delta,
			source_id,
			&"SettleCommand"
		)
		commands.append(morale_cmd)
	return commands
