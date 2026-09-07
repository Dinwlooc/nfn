## 请求启动濒死临时阶段（仅入栈，延迟启动）
extends StageRequestCommand
class_name DyingStageRequestCommand

## @context
class Context extends StageRequestCommand.Context:
	var dying_player: Player

## @seam_override
func _init(
	dying_player: Player,
	name_overriding: StringName = &"RequestDyingStage",
	context_overriding: Context = Context.new()
) -> void:
	super._init(dying_player.get_id(), name_overriding, context_overriding)
	context_overriding.dying_player = dying_player

## 静态初始化：校验并设置 stage，若已存在则完成
static func do_init(context: Context, game_state: GameState) -> void:
	if context.is_virtual:
		return
	for stage in game_state.stage_manager.temp_stage_stack:
		if stage is StageDying:
			context.phase = Context.Phase.DONE
			return
	context.stage = StageDying.new(context.dying_player)

## @hook
func _on_init_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	do_init(context_overriding as Context, game_state)
