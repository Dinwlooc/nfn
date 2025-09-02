extends RefCounted
class_name Stage

var system:System
var stage_name: StringName = &"Null"
var time_limit: float = 30.0
var event_processor: EventProcessor
var is_exit:bool = false
var timer:GameTimer
signal stage_ended

func _init(p_system:System,p_timer:GameTimer) -> void:
	system = p_system
	event_processor = system.event_processor
	timer = p_timer
	_init_expand()

func  _init_expand()->void:
	pass

func enter()->void:
	timer.timer_create(time_limit)
	timer.timeout.connect(on_timeout)
	enter_expand()

func enter_expand()->void:
	pass

func exit():
	end_stage()
	GlobalRegistry.timer.timeout.disconnect(on_timeout)
	GlobalRegistry.timer.timer_stop()
	is_exit = true
	system.stage_ended()

func handle_operation(op_data:OperationRequest):
	pass

func on_timeout()->void:
	exit()
	
func end_stage()->void:
	pass
	
func complete_stage() -> void:
	exit()
