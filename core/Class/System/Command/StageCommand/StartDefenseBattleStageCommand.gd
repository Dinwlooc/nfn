class_name StartDefenseBattleStageCommand
extends StartTempStageCommand

# 内部 Context，继承自父类的 Context
class Context extends StartTempStageCommand.Context:
	var defense_area: AreaDefence
	var attacker: Player

# 内部 Stage，继承自 Stage
class StageDefense extends Stage:
	var defense_area: AreaDefence
	var attacker: Player
	var defender: Player
	func _init(defense_area: AreaDefence, attacker: Player) -> void:
		super._init()
		self.defense_area = defense_area
		self.attacker = attacker
		self.defender = defense_area.player
		stage_name = &"DefenseBattle"
	# 阶段进入时的扩展（具体逻辑留空）
	func enter_expand(game_state: GameState) -> void:
		# TODO: 后续实现阶段细节
		pass
	# 阶段主逻辑（具体逻辑留空）
	func run(game_state: GameState) -> void:
		# TODO: 后续实现阶段细节
		pass
# 构造函数
func _init(defense_area: AreaDefence, attacker: Player,name_overriding:StringName = &"StartTempStage", context_overriding:Context = Context.new()) -> void:
	super._init(attacker.player_id ,name_overriding,context_overriding)
	_context.defense_area = defense_area
	_context.attacker = attacker

func _on_init_phase(game_state: GameState, _context: StartTempStageCommand.Context) -> void:
	_context.stage = StageDefense.new(_context.defense_area,_context.attacker)
	_context.phase = Context.Phase.DONE
