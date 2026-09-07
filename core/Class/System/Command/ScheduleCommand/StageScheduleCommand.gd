## 阶段调度命令：统一处理回滚、主阶段切换、启动临时阶段、结束当前阶段
extends ScheduleCommand
class_name StageScheduleCommand

enum Operation {
	ROLLBACK,
	SWITCH_MAIN,
	START_TEMP,
	END_CURRENT,
}

## @context @deep_inherit
class Context extends CommandContext:
	var operation: Operation
	var skip_count: int = 0
	var disallowed_stages: Array[StringName] = []

## @seam_override
func _init(
	command_bus: CommandBus,
	operation: Operation,
	skip_count: int = 0,
	disallowed: Array[StringName] = [],
	name_overriding: StringName = &"StageSchedule",
	context_overriding: Context = Context.new()
) -> void:
	super._init(command_bus, name_overriding, context_overriding)
	context_overriding.operation = operation
	context_overriding.skip_count = skip_count
	context_overriding.disallowed_stages = disallowed

## 静态执行：根据操作调用StageManager
static func do_execute(context: Context, game_state: GameState, command_bus: CommandBus) -> void:
	match context.operation:
		Operation.ROLLBACK:
			game_state.stage_manager.rollback_stage(game_state, command_bus)
		Operation.SWITCH_MAIN:
			game_state.stage_manager.switch_to_main_stage(game_state, context.skip_count, context.disallowed_stages, command_bus)
		Operation.START_TEMP:
			game_state.stage_manager.start_pending_temp_stage(game_state, command_bus)
		Operation.END_CURRENT:
			game_state.stage_manager.end_current_stage(game_state, command_bus)

## @hook
func execute(game_state: GameState) -> void:
	if _context.is_cancelled:
		complete()
		return
	if _context.is_virtual:
		complete()
		return
	var ctx: Context = _context
	do_execute(ctx, game_state, _command_bus)
	complete()
