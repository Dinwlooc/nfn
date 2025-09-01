extends RefCounted
class_name Stage

var system:System
var stage_name: StringName = &"Null"
var time_limit: float = 30.0
var event_processor: EventProcessor
signal stage_ended

func _init(p_system:System) -> void:
	system = p_system
	event_processor = system.event_processor
	_init_expand()

func  _init_expand()->void:
	pass

func enter()->void:
	GlobalConsole.timer.timer_create(time_limit)
	GlobalConsole.timer.timeout.connect(on_timeout)
	enter_expand()

func enter_expand()->void:
	pass

func exit():
	end_stage()
	GlobalConsole.timer.timeout.disconnect(on_timeout)
	GlobalConsole.timer.timer_stop()
	system.stage_ended()

func handle_operation(op_data:OperationRequest):
	pass

func on_timeout()->void:
	exit()
	
func end_stage()->void:
	pass
	
func complete_stage() -> void:
	exit()
