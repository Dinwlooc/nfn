extends RefCounted
class_name EventProcessor

var behavior_stack: Array[BehaviorEvent] = []
var system: System
var is_empty: bool = true
signal all_completed()

func _init(init_system: System):
	system = init_system

func process():
	if behavior_stack.is_empty():
		if !is_empty:
			is_empty = true
			system.enable_processing(false)
			all_completed.emit()
		return
	var current_behavior:BehaviorEvent = behavior_stack.back()
	current_behavior.execute(system)
	_send_to_modifiers(current_behavior)
	if current_behavior.is_completed:
		behavior_stack.pop_back()

func queue_behavior(event: BehaviorEvent):
	behavior_stack.push_back(event)
	if is_empty:
		is_empty = false
		system.enable_processing(true)

# 将行为事件分发给修饰器
func _send_to_modifiers(behavior: BehaviorEvent):
	# 这里实现修饰器系统的回调
	# 示例: ModifierSystem.process_behavior(behavior)
	pass
