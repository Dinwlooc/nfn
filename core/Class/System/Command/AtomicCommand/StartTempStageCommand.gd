class_name StartTempStageCommand
extends BehaviorCommand

class Context extends CommandContext:
	var stage: Stage
	func _init(p_stage: Stage) -> void:
		stage = p_stage
# 命令构造函数，接收玩家 ID 和上下文对象
func _init(player_id: int, context: Context) -> void:
	super._init(player_id, &"StartTempStage", context)
# 执行命令：通过 GameState 发出请求临时阶段的信号
func execute(game_state: GameState) -> void:
	var ctx = _context as Context
	if ctx and ctx.stage:
		game_state.request_temp_stage.emit(ctx.stage)
	complete()
