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

	func get_primary_modifier_player_ids() -> PackedInt32Array:
		var ids: PackedInt32Array = []
		if settle_card:
			var owner_id = settle_card.get_owner_id()
			if owner_id != 0:
				ids.append(owner_id)
		if oppose_card:
			var owner_id = oppose_card.get_owner_id()
			if owner_id != 0 and owner_id != (ids[0] if ids.size() > 0 else -0):
				ids.append(owner_id)
		return ids

	func get_primary_modifier_cards() -> Array[Card]:
		var cards: Array[Card] = []
		if settle_card:
			cards.append(settle_card)
		if oppose_card:
			cards.append(oppose_card)
		return cards

## @seam_override
func _init(
	player_id: int,
	target_defensive_area: AreaDefence,
	attacker: Player,
	name_overriding: StringName = &"Settle",
	context_overriding: Context = Context.new()
) -> void:
	context_overriding.set_defensive_area(target_defensive_area).set_attacker(attacker)
	super._init(player_id, name_overriding, context_overriding)

## @template
func execute(game_state: GameState) -> void:
	if _context.is_cancelled:
		complete()
		return
	var ctx: Context = _context
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

## 静态准备阶段：初始化守区，获取结算牌和对抗牌，连接监听
static func do_prepare(context: Context, game_state: GameState, command_owner: SettleCommand) -> void:
	if context.is_virtual:
		context.phase = Context.Phase.DONE
		return
	if not context.defensive_area:
		push_error("防御区域未设置")
		context.phase = Context.Phase.DONE
		return
	context.defensive_area.settle_defense_area()
	context.settle_card = context.defensive_area.get_top_card()
	if context.defensive_area.get_second_card() and context.defensive_area.get_second_card().player != context.settle_card.player:
		context.oppose_card = context.defensive_area.get_second_card()
	context.is_unilateral = (context.oppose_card == null)

	if context.settle_card:
		if not context.settle_card.area_changed.is_connected(command_owner._on_card_area_changed):
			context.settle_card.area_changed.connect(command_owner._on_card_area_changed)
	if context.oppose_card:
		if not context.oppose_card.area_changed.is_connected(command_owner._on_card_area_changed):
			context.oppose_card.area_changed.connect(command_owner._on_card_area_changed)

## 静态攻击判断阶段：创建拼点命令（双边）并连接回调
static func do_attack_judge(context: Context, game_state: GameState, command_owner: SettleCommand) -> void:
	if context.is_virtual:
		context.phase = Context.Phase.DONE
		return
	if not context.settle_card:
		context.phase = Context.Phase.DONE
		return
	context.settle_result = RuleSettle.get_initial_info(
		context.settle_card, context.oppose_card, context.is_unilateral,
		context.attacker, context.defensive_area.player, {}
	)
	if not context.is_unilateral and context.oppose_card.player != context.settle_card.player:
		var duel: DuelCommand = DuelCommand.new(context.settle_card, context.oppose_card, &"Settle")
		duel.duel_completed.connect(command_owner._on_opponent_duel_completed)
		command_owner.append_companion_command(duel)

## 静态伤害阶段：应用伤害和战意，创建 DamageCommand 和 MoraleCommand
static func do_damage(context: Context, game_state: GameState, command_owner: SettleCommand) -> void:
	if context.is_virtual:
		context.phase = Context.Phase.DONE
		return
	if not context.settle_card or not context.settle_result:
		context.phase = Context.Phase.DONE
		return
	# 处理战意
	var rules: Dictionary[StringName,Variant] = RuleSettle._get_merged_rules(context.settle_card, {})
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
	_apply_combat_will_grants_with_command(grants, context, command_owner)

	# 处理伤害
	if not context.settle_result.target:
		return
	var damage_cmd := DamageCommand.new(
		context.settle_result.target,
		context.settle_result.health_damage_value,
		context.settle_result.mental_damage_value,
		DamageCommand.SourceMechanism.GENERAL,
		context.settle_card.get_owner_id()
	)
	command_owner.append_companion_command(damage_cmd)

## 静态清理阶段：将防御区所有牌移到弃牌堆
static func do_clear(context: Context, game_state: GameState, command_owner: SettleCommand) -> void:
	if context.is_virtual:
		context.phase = Context.Phase.DONE
		return
	var transfer_cmd := CardTransferCommand.new(
		game_state.get_player_by_id(context.player_id),
		context.defensive_area,
		game_state.get_discard_area(),
		CardTransferCommand.Context.MoveOutMode.TOP,
		context.defensive_area.card_count()
	)
	command_owner.append_companion_command(transfer_cmd)

## 静态完成：断开所有信号监听
static func do_done(context: Context, command_owner: SettleCommand) -> void:
	if context.settle_card and context.settle_card.area_changed.is_connected(command_owner._on_card_area_changed):
		context.settle_card.area_changed.disconnect(command_owner._on_card_area_changed)
	if context.oppose_card and context.oppose_card.area_changed.is_connected(command_owner._on_card_area_changed):
		context.oppose_card.area_changed.disconnect(command_owner._on_card_area_changed)

## 辅助静态方法：将战意授予转换为 MoraleCommand
static func _apply_combat_will_grants_with_command(
	grants: Array[RuleSettle.CombatWillGrant],
	context: Context,
	command_owner: SettleCommand
) -> void:
	var source_id: int = context.settle_card.get_owner_id() if context.settle_card else 0
	for grant in grants:
		var player: Player = grant.target_player
		if not player:
			continue
		var total_value: int = grant.base_value + grant.extra_value
		if total_value <= 0:
			continue
		# 根据攻防类型决定增量赋值
		var attack_delta: int = total_value if not grant.is_defense else 0
		var defense_delta: int = total_value if grant.is_defense else 0
		var morale_cmd := MoraleCommand.new(
			player,
			attack_delta,
			defense_delta,
			source_id,
			&"SettleCommand"
		)
		command_owner.append_companion_command(morale_cmd)

## @hook
func _on_prepare_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	do_prepare(context_overriding as Context, game_state, self)

## @hook
func _on_attack_judge_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	do_attack_judge(context_overriding as Context, game_state, self)

## @hook
func _on_damage_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	do_damage(context_overriding as Context, game_state, self)
## 纯修饰位点。设计如此。
## @hook
func _on_effect_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	pass

## @hook
func _on_clear_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	do_clear(context_overriding as Context, game_state, self)

## @hook
func _on_done_phase(_game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	do_done(context_overriding as Context, self)
	complete()

## @signal_listener
func _on_opponent_duel_completed(result: int, diff: int) -> void:
	var ctx := _context as Context
	if not ctx:
		return
	ctx.duel_result = result
	ctx.duel_diff = diff
	# 仅当 attacker 不是守区玩家且非单边时进行衰减计算
	if ctx.attacker == ctx.defensive_area.player or ctx.is_unilateral:
		return
	var settle_card := ctx.settle_card
	if not settle_card:
		return
	var rules: Dictionary = RuleSettle._get_merged_rules(settle_card, {})
	var health_mode = rules.get(RuleSettle.Validator.LIFE_DAMAGE_MODE, RuleSettle.DamageMode.NONE)
	var mental_mode = rules.get(RuleSettle.Validator.MENTAL_DAMAGE_MODE, RuleSettle.DamageMode.NONE)
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

## @signal_listener
func _on_card_area_changed(card: Card) -> void:
	var ctx := _context as Context
	if not ctx:
		return
	if card == ctx.settle_card:
		ctx.settle_card = null
		card.area_changed.disconnect(_on_card_area_changed)
	elif card == ctx.oppose_card:
		ctx.oppose_card = null
		card.area_changed.disconnect(_on_card_area_changed)
