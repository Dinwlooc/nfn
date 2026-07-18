extends Stage
class_name StageStart

func _init() -> void:
	super._init()
	stage_name = &"Start"

func enter(game_state: GameState, command_bus: CommandBus) -> void:
	super.enter(game_state, command_bus)
	end_stage(game_state, command_bus)
