extends BehaviorCommand
class_name SettleCommand

## 结算上下文类
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
	## 预计算的结算结果（攻击判断阶段创建，拼点后衰减更新）
	var settle_result: RuleSettle.Result = null

	func get_settle_card() -> Card:
		return settle_card

	func get_oppose_card() -> Card:
		return oppose_card

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

	func set_defensive_area(area: AreaDefence) -> void:
		if phase != Phase.PREPARE:
			push_error("只能在预备阶段设置守区")
			return
		defensive_area = area

	func set_attacker(player: Player) -> void:
		if phase != Phase.PREPARE:
			push_error("只能在预备阶段设置攻击者")
			return
		attacker = player

	func set_settle_card(card: Card) -> void:
		if phase != Phase.PREPARE and phase != Phase.ATTACK_JUDGE:
			push_error("只能在预备阶段或攻击判断阶段重设结算牌")
			return
		settle_card = card

	func set_oppose_card(card: Card) -> void:
		if phase != Phase.PREPARE and phase != Phase.ATTACK_JUDGE:
			push_error("只能在预备阶段或攻击判断阶段重设对抗牌")
			return
		oppose_card = card

func _init(player_id: int, target_defensive_area: AreaDefence, attacker: Player, name_overriding: StringName = &"Settle", context_overriding: Context = Context.new()) -> void:
	super._init(player_id, name_overriding, context_overriding)
	_context.defensive_area = target_defensive_area
	_context.attacker = attacker

func execute(game_state: GameState) -> void:
	match _context.phase:
		Context.Phase.PREPARE:
			_on_prepare_phase(game_state, _context)
		Context.Phase.ATTACK_JUDGE:
			_on_attack_judge_phase(game_state, _context)
		Context.Phase.DAMAGE:
			_on_damage_phase(game_state, _context)
		Context.Phase.EFFECT:
			_on_effect_phase(game_state, _context)
		Context.Phase.CLEAR:
			_on_clear_phase(game_state, _context)
		Context.Phase.DONE:
			_on_done_phase(game_state, _context)

func _on_prepare_phase(game_state: GameState, ctx: Context) -> void:
	if not ctx.defensive_area:
		push_error("防御区域未设置")
		ctx.phase = Context.Phase.DONE
		return
	ctx.defensive_area.settle_defense_area()
	ctx.settle_card = ctx.defensive_area.get_top_card()
	if ctx.defensive_area.get_second_card() and ctx.defensive_area.get_second_card().player != ctx.settle_card.player:
		ctx.oppose_card = ctx.defensive_area.get_second_card()
	ctx.is_unilateral = (ctx.oppose_card == null)
	if ctx.settle_card:
		if not ctx.settle_card.area_changed.is_connected(_on_card_area_changed):
			ctx.settle_card.area_changed.connect(_on_card_area_changed)
	if ctx.oppose_card:
		if not ctx.oppose_card.area_changed.is_connected(_on_card_area_changed):
			ctx.oppose_card.area_changed.connect(_on_card_area_changed)
	ctx.phase = Context.Phase.ATTACK_JUDGE

func _on_attack_judge_phase(game_state: GameState, ctx: Context) -> void:
	if not ctx.settle_card:
		ctx.phase = Context.Phase.DONE
		return
	ctx.settle_result = RuleSettle.get_initial_info(
		ctx.settle_card, ctx.oppose_card, ctx.is_unilateral,
		ctx.attacker, ctx.defensive_area.player, {}
	)
	if not ctx.is_unilateral and ctx.oppose_card.player != ctx.settle_card.player:
		var duel: DuelCommand = DuelCommand.new(ctx.player_id)
		duel._context.set_cards(ctx.settle_card, ctx.oppose_card, &"Settle")
		duel.duel_completed.connect(_on_opponent_duel_completed)
		append_companion_command(duel)
	ctx.phase = Context.Phase.DAMAGE

func _on_opponent_duel_completed(result: int, diff: int) -> void:
	var ctx := _context as Context
	if not ctx:
		return
	ctx.duel_result = result
	ctx.duel_diff = diff
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

func _on_damage_phase(game_state: GameState, ctx: Context) -> void:
	if not ctx.settle_card or not ctx.settle_result:
		ctx.phase = Context.Phase.DONE
		return
	var rules: Dictionary = RuleSettle._get_merged_rules(ctx.settle_card, {})
	var mask: int = rules.get(RuleSettle.Validator.COMBAT_WILL_MODE, 0)
	var grants: Array[RuleSettle.CombatWillGrant] = RuleSettle.generate_combat_will_grants(
		ctx.settle_card,
		ctx.oppose_card,
		ctx.duel_result,
		ctx.duel_diff,
		ctx.is_unilateral,
		mask,
		ctx.attacker,
		ctx.defensive_area.player
	)
	# 不再直接应用，而是收集后创建 MoraleCommand
	_apply_combat_will_grants_with_command(grants)
	if not ctx.settle_result.target:
		ctx.phase = Context.Phase.EFFECT
		return
	var damage_cmd := DamageCommand.new(
		ctx.settle_result.target,
		ctx.settle_result.health_damage_value,
		ctx.settle_result.mental_damage_value,
		DamageCommand.SourceMechanism.GENERAL,
		ctx.settle_card.get_owner_id()
	)
	append_companion_command(damage_cmd)
	ctx.phase = Context.Phase.EFFECT

## 将战意授予列表转换为每个玩家的战意命令
func _apply_combat_will_grants_with_command(grants: Array[RuleSettle.CombatWillGrant]) -> void:
	var player_deltas: Dictionary = {}  # key: Player, value: {attack: int, defense: int}
	for grant in grants:
		var player: Player = grant.target_player
		if not player:
			continue
		var total_value: int = grant.base_value + grant.extra_value
		if total_value <= 0:
			continue
		if not player_deltas.has(player):
			player_deltas[player] = {&"attack": 0, &"defense": 0}
		if grant.is_defense:
			player_deltas[player][&"defense"] += total_value
		else:
			player_deltas[player][&"attack"] += total_value
	for player: Player in player_deltas:
		var attack_delta: int = player_deltas[player][&"attack"]
		var defense_delta: int = player_deltas[player][&"defense"]
		if attack_delta == 0 and defense_delta == 0:
			continue
		var source_id: int = 0
		if _context.settle_card:
			source_id = _context.settle_card.get_owner_id()
		var morale_cmd := MoraleCommand.new(player, attack_delta, defense_delta, source_id, &"SettleCommand")
		append_companion_command(morale_cmd)

func _on_effect_phase(game_state: GameState, ctx: Context) -> void:
	ctx.phase = Context.Phase.CLEAR

func _on_clear_phase(game_state: GameState, ctx: Context) -> void:
	var transfer_cmd := CardTransferCommand.new(ctx.player_id,
		ctx.defensive_area,
		game_state.get_discard_area(),
		CardTransferCommand.Context.MoveOutMode.TOP,
		ctx.defensive_area.card_count()
	)
	append_companion_command(transfer_cmd)
	ctx.phase = Context.Phase.DONE

func _on_done_phase(_game_state: GameState, ctx: Context) -> void:
	_disconnect_card_listeners(ctx)
	complete()

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

func _disconnect_card_listeners(ctx: Context) -> void:
	if ctx.settle_card and ctx.settle_card.area_changed.is_connected(_on_card_area_changed):
		ctx.settle_card.area_changed.disconnect(_on_card_area_changed)
	if ctx.oppose_card and ctx.oppose_card.area_changed.is_connected(_on_card_area_changed):
		ctx.oppose_card.area_changed.disconnect(_on_card_area_changed)
