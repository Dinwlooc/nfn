extends BaseEvent
class_name BehaviorEvent

var event_name: StringName
var current_phase: int = 0

func execute(system: System) -> void:
	complete()
