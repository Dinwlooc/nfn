# GameStartCommand.gd
extends BehaviorCommand
class_name GameStartCommand

enum Phase {
	INIT_SETUP,   # 初始化游戏设置
	START_DRAW,   # 开始初始抽牌
	DONE          # 完成
}

func _init() -> void:
	_context = CommandContext.new()
	super._init(-1,&"GameStart")
	_context.phase = Phase.INIT_SETUP

func execute(game_state: GameState) -> void:
	if _context.is_cancelled:
		complete()
		return
	if _context.is_virtual:
		_context.phase = Phase.DONE
		complete()
		return
	match _context.phase:
		Phase.INIT_SETUP:
			on_init_setup_phase(game_state)
		Phase.START_DRAW:
			on_start_draw_phase(game_state)
		Phase.DONE:
			on_done_phase(game_state)

func on_init_setup_phase(game_state: GameState) -> void:
	if game_state.network_manager:
		for user in game_state.network_manager.users:
			game_state.player_manager.add_player(user.id)
	else:
		game_state.player_manager.add_player(1)
	game_state.player_manager.ensure_min_players(2)
	game_state.current_player_index = 0  # 简化为始终从0号玩家开始
	_context.phase = Phase.START_DRAW

func on_start_draw_phase(game_state: GameState) -> void:
	var new_round_cmd = NewRoundCommand.new(0)
	append_companion_command(new_round_cmd)
	for i in range(game_state.player_manager.players.size()):
		var draw_cmd = DrawCardsCommand.new(i, 4)
		append_companion_command(draw_cmd)
	_context.phase = Phase.DONE
	complete()
	GlobalConsole._print("GameStartCommand:游戏初始化完成")

func on_done_phase(game_state: GameState) -> void:
	complete()
