## 单射容器：命令名→单一修饰器映射
extends ModifierContainer
class_name MapContainer

var mapping: Dictionary[StringName, Modifier] = {}

## 设置整个修饰器映射
func set_mapping(new_mapping: Dictionary[StringName, Modifier]) -> void:
	mapping = new_mapping

## 更新指定命令的修饰器
func update_modifier(command: StringName, modifier: Modifier) -> void:
	mapping[command] = modifier

## 处理命令
func process_command(command: BehaviorCommand) -> void:
	var modifier = mapping.get(command.event_name, null)
	if modifier:
		modifier.process_command(command)
