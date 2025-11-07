extends BehaviorCommand
class_name NewRoundCommand

var _new_round_player_id:int

func _init(player_id:int):
	super._init(&"stage_transition")
	_new_round_player_id = player_id
func execute(system: System) -> void:
	system.stage_manager.call_deferred(&"start_round",_new_round_player_id)
	complete()
