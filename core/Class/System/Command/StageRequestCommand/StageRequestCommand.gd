## 阶段请求命令基类：三阶段模式，子类重写 _on_request_phase 构造 stage
extends BehaviorCommand
class_name StageRequestCommand

class Context extends CommandContext:
	enum Phase { INIT, REQUEST, DONE }
	var stage: Stage = null

func _init(player_id: int, name_overriding: StringName = &"StageRequest", context_overriding: Context = Context.new()) -> void:
	super._init(player_id, name_overriding, context_overriding)

func execute(game_state: GameState) -> void:
	var ctx :Context= _context as Context
	match ctx.phase:
		Context.Phase.INIT:
			_on_init_phase(game_state)
		Context.Phase.REQUEST:
			_on_request_phase(game_state)
		Context.Phase.DONE:
			_on_done_phase(game_state)
		_:
			complete()
## 初始化阶段，子类可重写进行参数校验等，默认直接进入 REQUEST
func _on_init_phase(_game_state: GameState) -> void:
	var ctx :Context= _context as Context
	ctx.phase = Context.Phase.REQUEST
## 请求阶段：子类必须设置 ctx.stage，然后调用 super._on_request_phase 或直接调 super，但为防止遗漏，提供默认实现检查 stage
func _on_request_phase(game_state: GameState) -> void:
	var ctx :Context= _context as Context
	if not ctx.stage:
		push_error("StageRequestCommand: 未设置 stage")
		complete()
		return
	game_state.stage_manager.push_temp_stage(ctx.stage)
	ctx.phase = Context.Phase.DONE
## 完成阶段，子类可重写做收尾工作，默认直接 complete
func _on_done_phase(_game_state: GameState) -> void:
	complete()
