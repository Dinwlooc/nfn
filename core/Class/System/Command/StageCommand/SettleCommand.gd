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
	var attacker: Player = null
	var top_card: Card = null
	var second_card: Card = null
	var is_unilateral: bool = false
	var duel_result: int = 3
	var duel_diff: int = 0

## 结算命令
func _init(player_id: int, name_overriding: StringName = &"Settle", context_overriding: Context = Context.new()) -> void:
	super._init(player_id, name_overriding, context_overriding)

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
	if not _context.attacker:
		push_error("攻击者未设置")
		_context.phase = Context.Phase.DONE
		return
	_context.top_card = _context.defensive_area.get_top_card()
	_context.second_card = _context.defensive_area.get_second_card()
	_context.is_unilateral = (_context.second_card == null)
	_context.phase = Context.Phase.DUEL

func _on_duel_phase(game_state: GameState, _context: Context) -> void:
	if not _context.is_unilateral:
		var duel:DuelCommand = DuelCommand.new(_context.player_id)
		duel._context.set_cards(_context.top_card,_context.second_card,&"Settle")
		duel.duel_completed.connect(_on_duel_completed)
		append_companion_command(duel)
	_context.phase = Context.Phase.DAMAGE

func _on_damage_phase(game_state: GameState, _context: Context) -> void:
	var defender:Player = _context.defensive_area.player
	if _context.top_card.type == &"attack":
		var health_dmg:int = _context.top_card.get_attribute(&"power")
		var mental_dmg:int = _context.top_card.get_attribute(&"power")
		if not _context.is_unilateral:
			match _context.duel_result:
				DuelCommand.Context.Result.A_WIN:  # 攻击牌胜
					mental_dmg = max(0, mental_dmg - _context.duel_diff)
				DuelCommand.Context.Result.TIE:
					var defense_power:int = _context.second_card.get_attribute(&"power")
					mental_dmg = max(0, mental_dmg - defense_power)
				DuelCommand.Context.Result.B_WIN:  # 防御牌胜
					var defense_power:int = _context.second_card.get_attribute(&"power")
					mental_dmg = max(0, mental_dmg - (_context.duel_diff + defense_power))
					health_dmg = max(0, health_dmg - _context.duel_diff)
		var damage_cmd = DamageCommand.new(
			defender,
			health_dmg,
			mental_dmg,
			DamageCommand.SourceMechanism.GENERAL,
			_context.attacker.player_id
		)
		append_companion_command(damage_cmd)
	elif _context.top_card.type == &"defence":  # 防御牌结算
		var mental_dmg:int = _context.top_card.get_attribute(&"power")
		if not _context.is_unilateral and _context.duel_result == DuelCommand.Context.Result.A_WIN:
			mental_dmg = max(0, mental_dmg - _context.duel_diff)
		var damage_cmd = DamageCommand.new(
			_context.attacker,
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
	var move_cmd := CardMoveCommand.new(_context.player_id, &"CardMove", CardMoveCommand.Context.new())
	move_cmd._context.source_area = _context.defensive_area
	move_cmd._context.target_area = game_state.area_discard
	move_cmd._context.set_top_mode(_context.defensive_area.get_all_cards().size())
	game_state.queue_behavior(move_cmd)
	_context.phase = Context.Phase.DONE

func _on_done_phase(game_state: GameState, _context: Context) -> void:
	complete()
## 工具方法：设置防御区域和攻击者
func set_defense_context(area: AreaDefence, attacker: Player) -> void:
	_context.defensive_area = area
	_context.attacker = attacker
## 拼点完成回调
func _on_duel_completed(result: DuelCommand.Context.Result, diff: int) -> void:
	_context.duel_result = result
	_context.duel_diff = diff
