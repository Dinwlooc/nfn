class_name StartDefenseBattleStageCommand
extends StartTempStageCommand

class Context extends StartTempStageCommand.Context:
	var defense_area: AreaDefence
	var attacker: Player

func _init(defense_area: AreaDefence, attacker: Player, name_overriding: StringName = &"StartTempStage") -> void:
	var ctx = Context.new()
	ctx.defense_area = defense_area
	ctx.attacker = attacker
	super._init(attacker.player_id, name_overriding)
	_context = ctx

func _on_init_phase(game_state: GameState, _context: StartTempStageCommand.Context) -> void:
	var ctx = _context as Context
	var has_defense_stage = false
	for stage in game_state.get_temp_stage():
		if stage is StageDefense:
			has_defense_stage = true
			break
	if not has_defense_stage and not ctx.defense_area.player == ctx.attacker:
		ctx.stage = StageDefense.new(ctx.defense_area, ctx.attacker)
	ctx.phase = Context.Phase.DONE
