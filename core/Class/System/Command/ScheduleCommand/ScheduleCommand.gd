## 调度命令抽象基类：固定 player_id = 1，子类实现 execute
@abstract
extends BehaviorCommand
class_name ScheduleCommand

@abstract func execute(game_state: GameState) -> void

## 构造函数固定 player_id = 1，仅允许覆盖命令名称和上下文
func _init(name_overriding: StringName = &"Schedule", context_overriding: CommandContext = CommandContext.NULL_CONTEXT) -> void:
	super._init(1, name_overriding, context_overriding)
