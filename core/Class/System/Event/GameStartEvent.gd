extends BehaviorEvent
class_name GameStartEvent

func _init():
	super._init(&"GameStart")

func generate_runtime_event(system: System) -> RuntimeEvent:
	return GameStartRuntime.new(system)

# 游戏开始运行时事件
class GameStartRuntime extends RuntimeEvent:
	var system: System

	func _init(init_system: System):
		system = init_system

	func execute(processor: EventProcessor) -> void:
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
		# 随机选择起始玩家
		#system.current_player_index = randi_range(0, system.player_manager.players.size()-1)
		system.current_player_index = 0
		var stage_event = StageTransitionEvent.new(System.GameStage.START)
		processor.queue_behavior(stage_event)
		for i in range(system.player_manager.players.size()):
			var draw_event = DrawCardsEvent.new(i, 4)
			processor.queue_behavior(draw_event)
		complete()
		GlobalConsole._print("System:游戏初始化完成")
