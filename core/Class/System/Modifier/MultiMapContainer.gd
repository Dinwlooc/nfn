## 多射容器：命令名→修饰器数组映射
extends ModifierContainer
class_name MultiMapContainer

var mapping: Dictionary[StringName, Array] = {} 
## 添加命令修饰器
func add_modifier(command: StringName, modifier: Modifier) -> void:
	if not mapping.has(command):
		mapping[command] = []
	mapping[command].append(modifier)
## 处理命令
func process_command(command: BehaviorCommand) -> void:
	var modifiers: Array = mapping.get(command.event_name, [])
	for modifier in modifiers:
		modifier.process_command(command)
