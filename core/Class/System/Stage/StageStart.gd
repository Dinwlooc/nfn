extends Stage
class_name StageStart

func _init(p_game_state: GameState) -> void:
	super._init(p_game_state)
	stage_name = &"Start"

func run() -> void:
	end_stage()
