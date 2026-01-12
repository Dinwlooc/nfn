extends BehaviorCommand
class_name NewRoundCommand

class Context extends CommandContext:
	var new_round_player_id:int

func _init(player_id:int,name_overriding:StringName = &"NewRound",context_overriding:Context = Context.new()):
	super._init(player_id,name_overriding,context_overriding)

func execute(game_state: GameState) -> void:
	game_state.start_new_round(_context.new_round_player_id)
	complete()
