extends Stage
class_name StageStart

func _init(p_system: System) -> void:
	super._init(p_system)
	stage_name = &"Start"

func run() -> void:
	end_stage()
