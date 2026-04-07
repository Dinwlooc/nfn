extends BehaviorCommand
class_name BattleCommand

class Context extends CommandContext:
	enum Phase {
		INIT,
		CREATE_DUEL,
		PROCESS_RESULT,
		DONE
	}
	var defensive_area: AreaDefence
	var top_card: Card
	var second_card: Card
	var duel_result: int = DuelCommand.Context.Result.TIE
	var duel_diff: int = 0
	func set_battle_params(area: AreaDefence, top: Card, second: Card) -> void:
		defensive_area = area
		top_card = top
		second_card = second

const BASE_MORALE_GAIN: int = 1
const MORALE_BONUS_WIN: int = 1

func _init(area: AreaDefence, top: Card, second: Card, name_overriding: StringName = &"Battle") -> void:
	super._init(0, name_overriding, Context.new())
	_context.set_battle_params(area, top, second)

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
	if _context.second_card.player == _context.top_card.player:
		_context.phase = Context.Phase.DONE
	_context.phase = Context.Phase.CREATE_DUEL

func _on_create_duel_phase(game_state: GameState, _context: Context) -> void:
	var duel_command := DuelCommand.new(0)
	duel_command._context.set_cards(_context.top_card, _context.second_card, &"BattleCommand")
	duel_command.duel_completed.connect(_on_duel_completed)
	append_companion_command(duel_command)
	_context.phase = Context.Phase.PROCESS_RESULT

func _on_process_result_phase(game_state: GameState, _context: Context) -> void:
	var player_top: Player = _context.top_card.player
	var player_second: Player = _context.second_card.player
	if not player_top or not player_second:
		_context.phase = Context.Phase.DONE
		return
	# 双方各获得1点基础战意（根据各自卡牌类型）
	_add_morale_by_card(player_top, _context.top_card, BASE_MORALE_GAIN)
	_add_morale_by_card(player_second, _context.second_card, BASE_MORALE_GAIN)
	# 胜利方额外获得1点战意
	match _context.duel_result:
		DuelCommand.Context.Result.A_WIN:
			_add_morale_by_card(player_top, _context.top_card, MORALE_BONUS_WIN)
		DuelCommand.Context.Result.B_WIN:
			_add_morale_by_card(player_second, _context.second_card, MORALE_BONUS_WIN)
		DuelCommand.Context.Result.TIE:
			pass
	GlobalConsole._print(["斗牌结束，玩家", player_top.player_id, "战意：攻击", player_top.morale_attack, "防御", player_top.morale_defense,
		"，玩家", player_second.player_id, "战意：攻击", player_second.morale_attack, "防御", player_second.morale_defense])
	_context.phase = Context.Phase.DONE

func _on_done_phase(game_state: GameState, _context: Context) -> void:
	complete()

## 根据卡牌类型增加对应战意（攻击牌加攻击战意，防御牌加防御战意）
func _add_morale_by_card(player: Player, card: Card, amount: int) -> void:
	if card.type == &"attack":
		player.morale_attack += amount
	else:
		player.morale_defense += amount

func _on_duel_completed(result: int, diff: int) -> void:
	_context.duel_result = result
	_context.duel_diff = diff
