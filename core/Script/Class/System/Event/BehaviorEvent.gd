extends BaseEvent
class_name BehaviorEvent

enum Phase { START, GENERATE, END }

var phase: int = Phase.START

func _init(init_name: StringName, init_player_id: int = -1):
	super._init(EventType.BEHAVIOR, init_name, init_player_id)

func generate_runtime_event(system: System) -> RuntimeEvent:
	return null
