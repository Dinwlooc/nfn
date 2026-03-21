extends Stage
class_name StageStart

func _init() -> void:
	super._init()
	stage_name = &"Start"

func run(game_state:GameState) -> void:
	end_stage(game_state)
