extends ScheduleCommand
class_name GameStartCommand

enum Phase {
	INIT_SETUP,
	START_DRAW,
	DONE
}

func _init(command_bus: CommandBus) -> void:
	super._init(command_bus, &"GameStart", CommandContext.new())
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
	if game_state.users:
		for user in game_state.users.values():
			game_state.player_manager.add_player(user.id)
	else:
		game_state.player_manager.add_player(1)
	game_state.player_manager.ensure_min_players(2)
	RuleTrans.send_player_delta_updates(game_state.player_manager.get_seated_players())
	_context.phase = Phase.START_DRAW

func on_start_draw_phase(game_state: GameState) -> void:
	var new_round_cmd := NewRoundCommand.new(_command_bus, 2)
	append_companion_command(new_round_cmd)
	for player in game_state.player_manager.players:
		var draw_cmd := DrawCardsCommand.new(player.get_id(), 4)
		append_companion_command(draw_cmd)
	_context.phase = Phase.DONE
	complete()
	GlobalConsole._print("GameStartCommand:游戏初始化完成")

func on_done_phase(_game_state: GameState) -> void:
	complete()
