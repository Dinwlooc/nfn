## 阶段请求命令基类：三阶段模式，子类重写 _on_init_phase 构造 stage
## @seam_override
extends BehaviorCommand
class_name StageRequestCommand

## @context
class Context extends CommandContext:
	enum Phase { INIT, REQUEST, DONE }
	var stage: Stage = null

## @seam_override
func _init(
	player_id: int,
	name_overriding: StringName = &"StageRequest",
	context_overriding: Context = Context.new()
) -> void:
	super._init(player_id, name_overriding, context_overriding)

## @template
func execute(game_state: GameState) -> void:
	if _context.is_cancelled:
		complete()
		return
	var ctx: Context = _context
	match ctx.phase:
		Context.Phase.INIT:
			ctx.phase = Context.Phase.REQUEST
			_on_init_phase(game_state, ctx)
		Context.Phase.REQUEST:
			ctx.phase = Context.Phase.DONE
			_on_request_phase(game_state, ctx)
		Context.Phase.DONE:
			_on_done_phase(game_state, ctx)

## 静态请求：执行阶段入栈
static func do_request(context: Context, game_state: GameState) -> void:
	if not context.stage:
		push_error("StageRequestCommand: 未设置 stage")
		return
	game_state.stage_manager.push_temp_stage(context.stage)

## @hook
## 初始化阶段，子类可重写进行参数校验等，默认直接进入 REQUEST
func _on_init_phase(_game_state: GameState, _context: Context) -> void:
	pass

## @hook
## 请求阶段：检查 stage 并压栈
func _on_request_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	do_request(context_overriding as Context, game_state)

## @hook
## 完成阶段，子类可重写做收尾工作，默认直接 complete
func _on_done_phase(_game_state: GameState, _context: CommandContext = _context as Context) -> void:
	complete()
