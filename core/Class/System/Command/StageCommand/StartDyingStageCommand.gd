## 启动濒死阶段的命令，继承自 StartTempStageCommand
class_name StartDyingStageCommand
extends StartTempStageCommand

## 上下文，携带濒死玩家实例
class Context extends StartTempStageCommand.Context:
	var dying_player: Player

## @param dying_player 濒死玩家实例
func _init(dying_player: Player) -> void:
	var ctx = Context.new()
	ctx.dying_player = dying_player
	super._init(dying_player.get_id(), &"StartDyingStage")
	_context = ctx

## 初始化阶段：创建 StageDying 实例
func _on_init_phase(game_state: GameState, _context: StartTempStageCommand.Context) -> void:
	var ctx := _context as Context
	for stage in game_state.get_temp_stage():
		if stage is StageDying:
			return
	ctx.stage = StageDying.new(ctx.dying_player)
	ctx.phase = Context.Phase.DONE
