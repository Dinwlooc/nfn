# StartTempStageCommand.gd
class_name StartTempStageCommand
extends BehaviorCommand

class Context extends CommandContext:
	var stage: Stage
	enum Phase { INIT, DONE }

func _init(player_id: int, name_overriding: StringName = &"StartTempStage") -> void:
	super._init(player_id, name_overriding, Context.new())

func execute(game_state: GameState) -> void:
	var ctx = _context as Context
	match ctx.phase:
		Context.Phase.INIT:
			_on_init_phase(game_state, ctx)
		Context.Phase.DONE:
			_on_done_phase(game_state, ctx)
		_:
			complete()

func _on_init_phase(_game_state: GameState, ctx: Context) -> void:
	push_warning("_on_init_phase 应该在子类中被覆盖")
	ctx.phase = Context.Phase.DONE

func _on_done_phase(game_state: GameState, ctx: Context) -> void:
	if ctx.stage:
		game_state.stage_manager.start_temp_stage(ctx.stage, game_state)
	RuleTrans.send_stage_switch_notify(game_state)
	complete()
