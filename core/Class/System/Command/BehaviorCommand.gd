extends BaseCommand
class_name BehaviorCommand

var event_name: StringName
var current_phase: int = 0

func execute(system: System) -> void:
	complete()
