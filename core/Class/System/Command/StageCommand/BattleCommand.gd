extends BehaviorCommand
class_name BattleCommand

## 斗牌上下文类
class Context extends CommandContext:
	enum Phase {
		INIT,           # 初始化阶段
		CREATE_DUEL,    # 创建拼点
		PROCESS_RESULT, # 处理结果
		DONE            # 完成
	}
	var defensive_area: AreaDefence
	var top_card: Card
	var pending_card: Card
	var duel_result: int = DuelCommand.Context.Result.TIE
	var duel_diff: int = 0

	func set_battle_params(area: AreaDefence, top: Card, pending: Card) -> void:
		defensive_area = area
		top_card = top
		pending_card = pending
const BASE_MORALE_GAIN:int= 1
const MORALE_BONUS_WIN:int =1

func _init(area: AreaDefence, top: Card, pending: Card, name_overriding: StringName = &"Battle") -> void:
	# 斗牌不需要指定玩家，传入0作为占位
	super._init(0, name_overriding, Context.new())
	_context.set_battle_params(area, top, pending)

func execute(game_state: GameState) -> void:
	match _context.phase:
		Context.Phase.INIT:
			_on_init_phase(game_state, _context)
		Context.Phase.CREATE_DUEL:
			_on_create_duel_phase(game_state, _context)
		Context.Phase.PROCESS_RESULT:
			_on_process_result_phase(game_state, _context)
		Context.Phase.DONE:
			_on_done_phase(game_state, _context)

func _on_init_phase(game_state: GameState, _context: Context) -> void:
	_context.phase = Context.Phase.CREATE_DUEL

func _on_create_duel_phase(game_state: GameState, _context: Context) -> void:
	var duel_command := DuelCommand.new(0)  # 玩家占位
	duel_command.duel_context.set_cards(_context.top_card, _context.pending_card, &"BattleCommand")
	duel_command.duel_completed.connect(_on_duel_completed)
	append_companion_command(duel_command)
	_context.phase = Context.Phase.PROCESS_RESULT

func _on_process_result_phase(game_state: GameState, _context: Context) -> void:
	# 等待拼点完成，这里只是状态机转移，实际结果由回调设置
	_context.phase = Context.Phase.DONE

func _on_done_phase(game_state: GameState, _context: Context) -> void:
	# 根据斗牌结果修改战意
	var attacker:Player = _context.pending_card.player   # 出牌方为攻击方
	var defender:Player = _context.defensive_area.player  # 守区所有者为防御方
	if not attacker or not defender:
		complete()
		return
	attacker.morale_attack += BASE_MORALE_GAIN
	defender.morale_defense += BASE_MORALE_GAIN
	# 胜利额外战意
	match _context.duel_result:
		DuelCommand.Context.Result.A_WIN:
			if _context.top_card.player == attacker:
				attacker.morale_attack += MORALE_BONUS_WIN
			elif _context.top_card.player == defender:
				defender.morale_defense += MORALE_BONUS_WIN
		DuelCommand.Context.Result.B_WIN:
			if _context.pending_card.player == attacker:
				attacker.morale_attack += MORALE_BONUS_WIN
			elif _context.pending_card.player == defender:
				defender.morale_defense += MORALE_BONUS_WIN
		DuelCommand.Context.Result.TIE:
			pass
	GlobalConsole._print(["斗牌结束，攻方战意：", attacker.morale_attack, "，守方战意：", defender.morale_defense])
	complete()

func _on_duel_completed(result: int, diff: int) -> void:
	_context.duel_result = result
	_context.duel_diff = diff
