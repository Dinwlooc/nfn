## 调度命令抽象基类：固定 player_id = 1，子类实现 execute，构造时注入 CommandBus
@abstract
extends BehaviorCommand
class_name ScheduleCommand

var _command_bus: CommandBus

@abstract func execute(game_state: GameState) -> void

## 构造函数：第一个参数为 command_bus
func _init(
	command_bus: CommandBus,
	name_overriding: StringName = &"Schedule",
	context_overriding: CommandContext = CommandContext.NULL_CONTEXT
) -> void:
	super._init(1, name_overriding, context_overriding)
	_command_bus = command_bus
