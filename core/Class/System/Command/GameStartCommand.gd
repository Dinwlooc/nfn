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

func execute(system: System) -> void:
	match current_phase:
		Phase.INIT_SETUP:
			var setup_event = GameSetupRuntime.new(system)
			setup_event.execute()
			current_phase = Phase.START_DRAW
		Phase.START_DRAW:
			var processor:CommandProcessor = system.command_processor
			var stage_event = StageTransitionCommand.new(System.GameStage.START)
			processor.queue_behavior(stage_event)
			for i in range(system.player_manager.players.size()):
				var draw_event = DrawCardsCommand.new(i, 4)
				processor.queue_behavior(draw_event)
			current_phase = Phase.DONE
		Phase.DONE:
			complete()
			GlobalConsole._print("System:游戏初始化完成")

# 游戏设置运行时事件（封装原子操作）
class GameSetupRuntime extends RuntimeCommand:
	var system: System
	func _init(init_system: System):
		system = init_system
	func execute() -> void:
		# 初始化游戏阶段
		system.game_stages = {
			System.GameStage.START: StageStart.new(system, system.timer),
			System.GameStage.DRAW: StageDraw.new(system, system.timer),
			System.GameStage.MAIN: StageMain.new(system, system.timer),
			System.GameStage.END: StageEnd.new(system, system.timer)
		}
		if system.network_manager:
			for user in system.network_manager.users:
				system.player_manager.add_player(user.id)
		else:
			system.player_manager.add_player(1)
		system.player_manager.ensure_min_players(2)
		system.current_player_index = 0  # 简化为始终从0号玩家开始
