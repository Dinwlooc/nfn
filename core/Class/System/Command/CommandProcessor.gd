extends RefCounted
class_name CommandProcessor

var behavior_stack: Array[BehaviorCommand] = []
var system: System
var is_empty: bool = true
signal all_completed()
signal command_processing(command:BehaviorCommand)

func _init(init_system: System):
	system = init_system

func process():
	if behavior_stack.is_empty():
		if !is_empty:
			is_empty = true
			system.enable_processing(false)
			all_completed.emit()
		return
	var current_behavior:BehaviorCommand = behavior_stack.back()
	current_behavior.execute(system)
	command_processing.emit(current_behavior)
	if current_behavior.is_cancelled:
		current_behavior.complete()
	if current_behavior.is_completed:
		behavior_stack.pop_back()

func queue_behavior(event: BehaviorCommand):
	behavior_stack.push_back(event)
	if is_empty:
		is_empty = false
		system.enable_processing(true)
