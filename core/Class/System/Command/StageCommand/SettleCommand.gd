class_name SettleCommand
extends BehaviorCommand

## 结算上下文类
class Context extends CommandContext:
	enum Phase {
		PREPARE,       # 预备阶段
		DUEL,          # 拼点判断阶段
		DAMAGE,        # 伤害阶段
		EFFECT,        # 效果阶段（供修饰机制使用）
		CLEAR,         # 守区清空阶段
		DONE           # 完成
	}
	var defensive_area: AreaDefence = null
	var attacker:Player = null
	var settle_card: Card = null       # 原 top_card -> 结算牌
	var oppose_card: Card = null       # 原 second_card -> 对抗牌
	var is_unilateral: bool = false
	var duel_result: int = 3
	var duel_diff: int = 0

	## 获取结算牌（顶层牌）
	func get_settle_card() -> Card:
		return settle_card

	## 获取对抗牌（次层牌）
	func get_oppose_card() -> Card:
		return oppose_card

	## 重写：获取主修饰玩家ID数组（结算牌拥有者优先，对抗牌拥有者其次）
	func get_primary_modifier_player_ids() -> PackedInt32Array:
		var ids: PackedInt32Array = []
		if settle_card:
			var owner_id = settle_card.get_owner_id()
			if owner_id != -1:
				ids.append(owner_id)
		if oppose_card:
			var owner_id = oppose_card.get_owner_id()
			if owner_id != -1 and owner_id != (ids[0] if ids.size() > 0 else -1):
				ids.append(owner_id)
		return ids

	## 重写：获取主修饰卡牌数组（结算牌在前，对抗牌在后）
	func get_primary_modifier_cards() -> Array[Card]:
		var cards: Array[Card] = []
		if settle_card:
			cards.append(settle_card)
		if oppose_card:
			cards.append(oppose_card)
		return cards

## 结算命令
func _init(player_id: int,target_defensive_area: AreaDefence,attacker:Player, name_overriding: StringName = &"Settle", context_overriding: Context = Context.new()) -> void:
	super._init(player_id, name_overriding, context_overriding)
	_context.defensive_area = target_defensive_area
	_context.attacker = attacker

func execute(game_state: GameState) -> void:
	match _context.phase:
		Context.Phase.PREPARE:
			_on_prepare_phase(game_state, _context)
		Context.Phase.DUEL:
			_on_duel_phase(game_state, _context)
		Context.Phase.DAMAGE:
			_on_damage_phase(game_state, _context)
		Context.Phase.EFFECT:
			_on_effect_phase(game_state, _context)
		Context.Phase.CLEAR:
			_on_clear_phase(game_state, _context)
		Context.Phase.DONE:
			_on_done_phase(game_state, _context)

func _on_prepare_phase(game_state: GameState, _context: Context) -> void:
	if not _context.defensive_area:
		push_error("防御区域未设置")
		_context.phase = Context.Phase.DONE
		return
	_context.defensive_area.settle_defense_area()
	_context.settle_card = _context.defensive_area.get_top_card()
	if _context.defensive_area.get_second_card() and not _context.defensive_area.get_second_card().player == _context.get_settle_card().player:
		_context.oppose_card = _context.defensive_area.get_second_card()
	_context.is_unilateral = (_context.oppose_card == null)
	_context.phase = Context.Phase.DUEL

func _on_duel_phase(game_state: GameState, _context: Context) -> void:
	if not _context.is_unilateral and not _context.get_oppose_card().player == _context.get_settle_card().player:
		var duel: DuelCommand = DuelCommand.new(_context.player_id)
		duel._context.set_cards(_context.settle_card, _context.oppose_card, &"Settle")
		duel.duel_completed.connect(_on_duel_completed)
		append_companion_command(duel)
	_context.phase = Context.Phase.DAMAGE

## 伤害阶段：调用 Rule 类计算伤害与战意，生成单个 DamageCommand
func _on_damage_phase(game_state: GameState, _context: Context) -> void:
	if not _context.settle_card:
		_context.phase = Context.Phase.DONE
		return
	var defender: Player = _context.defensive_area.player
	var attacker: Player = _context.attacker
	# 调用纯函数计算结算结果
	var result: RuleSettle.Result = RuleSettle.evaluate(
		_context.settle_card,
		_context.oppose_card,
		_context.duel_result,
		_context.duel_diff,
		_context.is_unilateral,
		attacker,
		defender,
		{}  # 暂不使用卡牌覆盖规则
	)
	_apply_combat_will_grants(result.combat_will_grants)
	# 确定伤害目标与数值
	var damage_target: Player = result.target
	if not damage_target:
		_context.phase = Context.Phase.EFFECT
		return
	var health_val: int = result.health_damage_value
	var mental_val: int = result.mental_damage_value
	var damage_cmd := DamageCommand.new(
		damage_target,
		health_val,
		mental_val,
		DamageCommand.SourceMechanism.GENERAL,
		_context.settle_card.get_owner_id()
	)
	append_companion_command(damage_cmd)
	_context.phase = Context.Phase.EFFECT
## 应用战意授予条目（直接操作 Player 属性）
static func _apply_combat_will_grants(grants: Array[RuleSettle.CombatWillGrant]) -> void:
	for grant in grants:
		var player: Player = grant.target_player
		if not player:
			continue
		var total_value: int = grant.base_value + grant.extra_value
		if total_value <= 0:
			continue
		if grant.is_defense:
			player.morale_defense += total_value
			continue
		player.morale_attack += total_value

func _on_effect_phase(game_state: GameState, _context: Context) -> void:
	_context.phase = Context.Phase.CLEAR

func _on_clear_phase(game_state: GameState, _context: Context) -> void:
	var transfer_cmd := CardTransferCommand.new(_context.player_id,
	_context.defensive_area,
	game_state.area_discard,
	CardTransferCommand.Context.MoveOutMode.TOP,
	_context.defensive_area.card_count()
	)
	game_state.queue_behavior(transfer_cmd)
	_context.phase = Context.Phase.DONE

func _on_done_phase(game_state: GameState, _context: Context) -> void:
	complete()

## 拼点完成回调
func _on_duel_completed(result: DuelCommand.Context.Result, diff: int) -> void:
	_context.duel_result = result
	_context.duel_diff = diff
