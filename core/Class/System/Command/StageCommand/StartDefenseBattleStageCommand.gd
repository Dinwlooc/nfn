class_name StartDefenseBattleStageCommand
extends StartTempStageCommand

# 内部 Context，继承自父类的 Context
class Context extends StartTempStageCommand.Context:
	var defense_area: AreaDefence
	var attacker: Player

# 构造函数
func _init(defense_area: AreaDefence, attacker: Player,name_overriding:StringName = &"StartTempStage", context_overriding:Context = Context.new()) -> void:
	super._init(attacker.player_id ,name_overriding,context_overriding)
	_context.defense_area = defense_area
	_context.attacker = attacker

func _on_init_phase(game_state: GameState, _context: StartTempStageCommand.Context) -> void:
	var has_defense_stage:bool = false
	for stage in game_state.get_temp_stage():
		if stage is StageDefense:
			has_defense_stage = true
			break
	if not has_defense_stage and not _context.defense_area.player == _context.attacker:
		_context.stage = StageDefense.new(_context.defense_area, _context.attacker)
	_context.phase = Context.Phase.DONE
