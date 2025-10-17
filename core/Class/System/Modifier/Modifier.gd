## 具体修饰器实现：链接到内部可调用体的中转类
extends ModifierContainer
class_name Modifier

var modifier_name: StringName
var command_name: StringName
var callable: Callable

func _init(name: StringName, command: StringName, callable_obj: Callable):
	modifier_name = name
	command_name = command
	callable = callable_obj

## 执行修饰操作
func process_command(command: BehaviorCommand) -> void:
	if command.event_name == command_name:
		callable.call(command)
