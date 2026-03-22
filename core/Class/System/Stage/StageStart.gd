extends Stage
class_name StageStart

func _init() -> void:
	super._init()
	stage_name = &"Start"

func enter(game_state:GameState) -> void:
	super.enter(game_state)
	end_stage(game_state)
