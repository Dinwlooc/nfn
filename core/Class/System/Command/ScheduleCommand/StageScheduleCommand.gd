## 阶段调度命令：统一处理回滚、主阶段切换、启动临时阶段
extends ScheduleCommand
class_name StageScheduleCommand

enum Operation {
	ROLLBACK,
	SWITCH_MAIN,
	START_TEMP,
}

class Context extends CommandContext:
	var operation: Operation
	var skip_count: int = 0
	var disallowed_stages: Array[StringName] = []

func _init(operation: Operation, skip_count: int = 0, disallowed: Array[StringName] = [], name_overriding: StringName = &"StageSchedule", context_overriding: Context = Context.new()) -> void:
	super._init(name_overriding, context_overriding)
	var ctx = _context as Context
	ctx.operation = operation
	ctx.skip_count = skip_count
	ctx.disallowed_stages = disallowed

func execute(game_state: GameState) -> void:
	var ctx = _context as Context
	match ctx.operation:
		Operation.ROLLBACK:
			game_state.stage_manager.rollback_stage(game_state)
		Operation.SWITCH_MAIN:
			game_state.stage_manager.switch_to_main_stage(game_state, ctx.skip_count, ctx.disallowed_stages)
		Operation.START_TEMP:
			game_state.stage_manager.start_pending_temp_stage(game_state)
	complete()
