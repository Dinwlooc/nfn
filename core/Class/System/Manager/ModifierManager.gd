extends RefCounted
class_name ModifierManager

var system: System
var modifiers: Array

func _init(init_system: System):
	system = init_system
# 注册修饰器
func register_modifier(modifier) -> void:
	if not modifiers.has(modifier):
		modifiers.append(modifier)
# 处理行为命令
func process_behavior(behavior: BehaviorCommand) -> void:
	modifiers.sort_custom(func(a, b): return a.priority < b.priority)
	for modifier in modifiers:
		if modifier.can_modify(behavior):
			modifier.modify(behavior)
