## 斗牌命令 - 重构后
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

	var defensive_area: AreaDefensive
	var top_card: Card
	var pending_card: Card
	var duel_result: int = DuelCommand.Context.Result.TIE
	var duel_diff: int = 0
	## 工具方法：设置战斗参数
	func set_battle_params(area: AreaDefensive, top: Card, pending: Card) -> void:
		defensive_area = area
		top_card = top
		pending_card = pending
## 斗牌命令
func _init(player_id: int,name_overriding: StringName,context_overriding: Context = Context.new()) -> void:
	super._init(player_id,name_overriding,context_overriding)

func execute(game_state: GameState) -> void:
	match _context.phase:
		Context.Phase.INIT:
			_on_init_phase(game_state, _context)
		Context.Phase.CREATE_DUEL:
			_on_create_duel_phase(game_state, _context)
		Context.Phase.DONE:
			_on_done_phase(game_state, _context)

func _on_init_phase(game_state: GameState, _context: Context) -> void:
	_context.phase = Context.Phase.CREATE_DUEL

func _on_create_duel_phase(game_state: GameState, _context: Context) -> void:
	var duel_command:DuelCommand = DuelCommand.new(_context.player_id)
	duel_command.duel_context.set_cards(_context.top_card, _context.pending_card, &"BattleCommand")
	duel_command.duel_completed.connect(_on_duel_completed)
	append_companion_command(duel_command)
	_context.phase = Context.Phase.PROCESS_RESULT

func _on_done_phase(game_state: GameState, _context: Context) -> void:
	match _context.duel_result:
		DuelCommand.Context.Result.A_WIN:
			pass
		DuelCommand.Context.Result.B_WIN:
			pass
		DuelCommand.Context.Result.TIE:
			pass
	complete()

## 拼点完成回调
func _on_duel_completed(result: int, diff: int) -> void:
	_context.duel_result = result
	_context.duel_diff = diff
