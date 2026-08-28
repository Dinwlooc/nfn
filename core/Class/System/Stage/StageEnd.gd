extends Stage
class_name StageEnd

func _init() -> void:
	super._init()
	stage_name = &"End"
	time_limit = 0.0

func enter(game_state: GameState, command_bus: CommandBus) -> void:
	super.enter(game_state, command_bus)
	request_end_stage(command_bus)
