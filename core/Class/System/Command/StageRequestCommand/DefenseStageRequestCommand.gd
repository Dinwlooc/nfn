## 请求启动防御战斗临时阶段（仅入栈，延迟启动）
extends StageRequestCommand
class_name DefenseStageRequestCommand


class Context extends StageRequestCommand.Context:
	var defense_area: AreaDefence
	var attacker: Player

func _init(defense_area: AreaDefence, attacker: Player, name_overriding: StringName = &"RequestDefenseBattleStage", context_overriding: Context = Context.new()) -> void:
	super._init(attacker.get_id(), name_overriding, context_overriding)
	var ctx = _context as Context
	ctx.defense_area = defense_area
	ctx.attacker = attacker

## 重写初始化阶段进行校验
func _on_init_phase(game_state: GameState) -> void:
	var ctx:Context = _context as Context
	for stage in game_state.stage_manager.temp_stage_stack:
		if stage is StageDefense:
			complete()
			return
	if ctx.defense_area.player == ctx.attacker:
		complete()
		return
	super._on_init_phase(game_state)

## 重写请求阶段，构造防御阶段并设置到 ctx.stage
func _on_request_phase(_game_state: GameState) -> void:
	var ctx:Context = _context as Context
	ctx.stage = StageDefense.new(ctx.defense_area, ctx.attacker)
	super._on_request_phase(_game_state)
