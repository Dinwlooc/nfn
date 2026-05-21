extends BehaviorCommand
class_name SwitchMainStageCommand

## 命令上下文
class Context extends CommandContext:
	var current_stage:Stage
	var current_player_id: int                     # 当前玩家ID（构造函数传入）
	var disallowed_stages: Array[StringName] = []  # 被禁止的主阶段名称（可外部注入）
	enum Phase { INIT, PREPARE, ENDING, TRANSITION, DONE }

## 构造函数
## @param current_player_id 当前玩家ID（必须）
func _init(current_player_id: int, name_overriding: StringName = &"SwitchMainStage") -> void:
	var ctx = Context.new()
	ctx.current_player_id = current_player_id
	super._init(current_player_id, name_overriding, ctx)

## 外部接口：设置被禁止的阶段列表（只能在 INIT 阶段调用）
func set_disallowed_stages(disallowed: Array[StringName]) -> void:
	var ctx = _context as Context
	if ctx.phase == Context.Phase.INIT:
		ctx.disallowed_stages = disallowed
	else:
		push_warning("SwitchMainStageCommand: 不能在 INIT 阶段之后设置禁止阶段")

func execute(game_state: GameState) -> void:
	var ctx = _context as Context
	match ctx.phase:
		Context.Phase.INIT:
			ctx.phase = Context.Phase.PREPARE
		Context.Phase.PREPARE:
			_on_prepare_phase(game_state, ctx)
		Context.Phase.ENDING:
			_on_ending_phase(game_state, ctx)
		Context.Phase.TRANSITION:
			_on_transition_phase(game_state, ctx)
		Context.Phase.DONE:
			_on_done_phase(game_state, ctx)
		_:
			complete()

## 预备阶段：获取当前主阶段实例，对应“主阶段结束时”修饰点
func _on_prepare_phase(game_state: GameState, ctx: Context) -> void:
	var cur_stage = game_state.stage_manager.current_stage
	if not cur_stage or cur_stage.is_temporary():
		push_error("SwitchMainStageCommand: 当前阶段不是主阶段，无法切换")
		complete()
		return
	ctx.current_stage = cur_stage
	ctx.phase = Context.Phase.ENDING

## 结束阶段：对应“主阶段结束后”修饰点
func _on_ending_phase(_game_state: GameState, ctx: Context) -> void:
	ctx.phase = Context.Phase.TRANSITION

## 转换阶段：计算跳过的阶段数量，请求切换，对应“主阶段开始时”修饰点
func _on_transition_phase(game_state: GameState, ctx: Context) -> void:
	var skip_counts:int = _calculate_skip_counts()
	# 调用管理器切换主阶段，传入跳过的阶段数量，如果后续阶段都被禁止，阶段管理器会自动推进回合轮转
	game_state.stage_manager.switch_to_main_stage(game_state, skip_counts)
	ctx.phase = Context.Phase.DONE

## 完成阶段：对应“主阶段开始后”修饰点
func _on_done_phase(_game_state: GameState, _ctx: Context) -> void:
	complete()

func _calculate_skip_counts()->int:
	if _context.disallowed_stages.is_empty():
		return 0
	var names = StageManager.MAIN_STAGE_NAMES
	var current_name:StringName = _context.current_stage.stage_name
	var idx:int = names.find(current_name)
	if idx == -1:
		return 0
	var target_idx:int = (idx + 1) % names.size()
	var steps:int = 0
	while _context.disallowed_stages.has(names[target_idx]) and steps < names.size():
		target_idx = (target_idx + 1) % names.size()
		steps += 1
	return steps
