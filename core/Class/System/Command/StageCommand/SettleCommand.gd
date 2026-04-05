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
func _init(player_id: int,target_defensive_area: AreaDefence, name_overriding: StringName = &"Settle", context_overriding: Context = Context.new()) -> void:
	super._init(player_id, name_overriding, context_overriding)
	_context.defensive_area = target_defensive_area

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

func _on_damage_phase(game_state: GameState, _context: Context) -> void:
	if not _context.settle_card:
		_context.phase = Context.Phase.DONE
		return
	var defender: Player = _context.defensive_area.player
	if _context.settle_card.type == &"attack":
		var health_dmg: int = _context.settle_card.get_attribute(&"power")
		var mental_dmg: int = _context.settle_card.get_attribute(&"power")
		if not _context.is_unilateral:
			var defense_power: int = _context.oppose_card.get_attribute(&"power")
			match _context.duel_result:
				DuelCommand.Context.Result.A_WIN:
					mental_dmg = max(0, mental_dmg - defense_power)
				DuelCommand.Context.Result.TIE:
					mental_dmg = max(0, mental_dmg - defense_power)
				DuelCommand.Context.Result.B_WIN:
					mental_dmg = max(0, mental_dmg - (_context.duel_diff + defense_power))
					health_dmg = max(0, health_dmg - _context.duel_diff)
		var damage_cmd = DamageCommand.new(
			defender,
			health_dmg,
			mental_dmg,
			DamageCommand.SourceMechanism.GENERAL,
			_context.get_settle_card().get_owner_id()
		)
		append_companion_command(damage_cmd)
	elif _context.settle_card.type == &"defence":
		var mental_dmg: int = _context.settle_card.get_attribute(&"power")
		if not _context.is_unilateral and _context.duel_result == DuelCommand.Context.Result.A_WIN:
			mental_dmg = max(0, mental_dmg - _context.duel_diff)
		var damage_cmd = DamageCommand.new(
			_context.get_oppose_card().player,
			0,
			mental_dmg,
			DamageCommand.SourceMechanism.GENERAL,
			defender.player_id
		)
		append_companion_command(damage_cmd)
	_context.phase = Context.Phase.EFFECT

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
