extends BehaviorCommand
class_name RollbackStageCommand

## 命令上下文
class Context extends CommandContext:
	var current_player_id: int           # 当前玩家ID（构造函数传入）
	var temp_stage: Stage                # 即将结束的临时阶段（构造函数传入）
	enum Phase { INIT, TRANSITION, DONE }

## 构造函数
## @param current_player_id 当前玩家ID
## @param temp_stage 即将结束的临时阶段实例
func _init(current_player_id: int, temp_stage: Stage, name_overriding: StringName = &"RollbackToMainStage") -> void:
	var ctx = Context.new()
	ctx.current_player_id = current_player_id
	ctx.temp_stage = temp_stage
	super._init(current_player_id, name_overriding, ctx)

func execute(game_state: GameState) -> void:
	var ctx = _context as Context
	match ctx.phase:
		Context.Phase.INIT:
			ctx.phase = Context.Phase.TRANSITION
		Context.Phase.TRANSITION:
			_on_transition_phase(game_state, ctx)
		Context.Phase.DONE:
			_on_done_phase(game_state, ctx)
		_:
			complete()

## 转换阶段：对应“临时阶段结束时”修饰点
func _on_transition_phase(game_state: GameState, ctx: Context) -> void:
	game_state.stage_manager.rollback_stage(game_state, ctx.current_player_id)
	ctx.phase = Context.Phase.DONE

## 完成阶段：对应“临时阶段结束后”修饰点
func _on_done_phase(_game_state: GameState, _ctx: Context) -> void:
	RuleTrans.send_stage_switch_notify(_game_state)
	complete()
