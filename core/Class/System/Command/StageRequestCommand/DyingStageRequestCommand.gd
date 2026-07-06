## 请求启动濒死临时阶段（仅入栈，延迟启动）
class_name DyingStageRequestCommand
extends StageRequestCommand

class Context extends StageRequestCommand.Context:
	var dying_player: Player

func _init(dying_player: Player, name_overriding: StringName = &"RequestDyingStage", context_overriding: Context = Context.new()) -> void:
	super._init(dying_player.get_id(), name_overriding, context_overriding)
	var ctx = _context as Context
	ctx.dying_player = dying_player

## 重写初始化阶段进行校验
func _on_init_phase(game_state: GameState) -> void:
	var ctx = _context as Context
	for stage in game_state.stage_manager.temp_stage_stack:
		if stage is StageDying:
			complete()
			return
	super._on_init_phase(game_state)

## 重写请求阶段，构造濒死阶段并设置到 ctx.stage
func _on_request_phase(_game_state: GameState) -> void:
	var ctx = _context as Context
	ctx.stage = StageDying.new(ctx.dying_player)
	super._on_request_phase(_game_state)
