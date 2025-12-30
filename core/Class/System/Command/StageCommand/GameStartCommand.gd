extends BehaviorCommand
class_name GameStartCommand

enum Phase {
	INIT_SETUP,   # 初始化游戏设置
	START_DRAW,   # 开始初始抽牌
	DONE          # 完成
}
func _init():
	super._init(&"GameStart")
	current_phase = Phase.INIT_SETUP

func execute(game_state: GameState) -> void:
	match current_phase:
		Phase.INIT_SETUP:
			var setup_event = GameSetupRuntime.new(game_state)
			setup_event.execute()
			current_phase = Phase.START_DRAW
		Phase.START_DRAW:
			var stage_event = NewRoundCommand.new(0)
			append_companion_command(stage_event)
			for i in range(game_state.player_manager.players.size()):
				var draw_event = DrawCardsCommand.new(i, 4)
				append_companion_command(draw_event)
			complete()
			GlobalConsole._print("GameStartCommand:游戏初始化完成")

# 游戏设置运行时事件（封装原子操作）
class GameSetupRuntime extends AtomicCommand:
	var game_state: GameState
	func _init(init_system: GameState):
		game_state = init_system
	func execute() -> void:
		if game_state.network_manager:
			for user in game_state.network_manager.users:
				game_state.player_manager.add_player(user.id)
		else:
			game_state.player_manager.add_player(1)
		game_state.player_manager.ensure_min_players(2)
		game_state.current_player_index = 0  # 简化为始终从0号玩家开始
