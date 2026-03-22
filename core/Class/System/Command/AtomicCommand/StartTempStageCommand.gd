class_name StartTempStageCommand
extends BehaviorCommand

class Context extends CommandContext:
	var stage: Stage
	enum Phase {
		INIT,           # 初始化阶段
		DONE            # 完成
	}
# 命令构造函数，接收玩家 ID 和上下文对象
func _init(player_id: int,name_overriding:StringName = &"StartTempStage", context_overriding:Context = Context.new()) -> void:
	super._init(player_id,name_overriding, context_overriding)
# 执行命令：通过 GameState 发出请求临时阶段的信号
func execute(game_state: GameState) -> void:
	match _context.phase:
		Context.Phase.INIT:
			_on_init_phase(game_state, _context)
		Context.Phase.DONE:
			_on_done_phase(game_state, _context)


func _on_init_phase(game_state: GameState, _context: Context) -> void:
	push_warning("_on_init_phase 应该在子类中被覆盖")
	_context.phase = Context.Phase.DONE

func _on_done_phase(game_state: GameState, _context: Context) -> void:
	if _context.stage:
		game_state.request_temp_stage.emit(_context.stage)
	complete()
