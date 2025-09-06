extends RefCounted
class_name EventProcessor

var behavior_stack: Array[BehaviorEvent] = []
var current_runtime: RuntimeEvent = null
var system:System
var is_empty:bool = true
signal all_completed()

func _init(init_system:System) -> void:
	system = init_system
# 处理循环
func process_events():
	if current_runtime:
		_process_runtime()
	elif behavior_stack.size() > 0:
		_process_behavior()
	else:
		all_completed.emit()
		is_empty = true
		system.enable_processing(false)
# 处理行为事件
func _process_behavior():
	var behavior = behavior_stack.back()
	match behavior.phase:
		BehaviorEvent.Phase.START:
			behavior.phase = BehaviorEvent.Phase.GENERATE
		BehaviorEvent.Phase.GENERATE:
			current_runtime = behavior.generate_runtime_event(system)
			behavior.phase = BehaviorEvent.Phase.END
		BehaviorEvent.Phase.END:
			behavior_stack.pop_back()
# 处理运行事件
func _process_runtime():
	current_runtime.execute(self)
	if current_runtime.is_completed:
		current_runtime = null
# 添加行为事件
func queue_behavior(event: BehaviorEvent):
	behavior_stack.push_back(event)
	system.enable_processing(true)
	is_empty = false
