## 请求启动防御战斗临时阶段（仅入栈，延迟启动）
extends StageRequestCommand
class_name DefenseStageRequestCommand

## @context
class Context extends StageRequestCommand.Context:
	var defense_area: AreaDefence
	var attacker: Player

## @seam_override
func _init(
	defense_area: AreaDefence,
	attacker: Player,
	name_overriding: StringName = &"RequestDefenseBattleStage",
	context_overriding: Context = Context.new()
) -> void:
	super._init(attacker.get_id(), name_overriding, context_overriding)
	context_overriding.defense_area = defense_area
	context_overriding.attacker = attacker

## 静态初始化：校验条件并设置 stage，若失败则设置 phase 为 DONE
static func do_init(context: Context, game_state: GameState) -> void:
	if context.is_virtual:
		return
	# 检查是否已存在防御阶段
	for stage in game_state.stage_manager.temp_stage_stack:
		if stage is StageDefense:
			context.phase = Context.Phase.DONE
			return
	# 检查不能自己打自己
	if context.defense_area.player == context.attacker:
		context.phase = Context.Phase.DONE
		return
	# 设置 stage
	context.stage = StageDefense.new(context.defense_area, context.attacker)

## @hook
func _on_init_phase(game_state: GameState, context_overriding: CommandContext = _context as Context) -> void:
	do_init(context_overriding as Context, game_state)
