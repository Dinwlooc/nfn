extends BehaviorCommand
class_name StageTransitionCommand

var target_stage: System.GameStage

func _init(p_target_stage: System.GameStage):
	super._init(&"stage_transition")
	target_stage = p_target_stage

func execute(system: System) -> void:
	var runtime_event = RuntimeStageTransitionCommand.new(system, target_stage)
	runtime_event.execute()
	complete()

class RuntimeStageTransitionCommand extends AtomicCommand:
	var system: System
	var target_stage: System.GameStage
	func _init(p_system: System, p_stage: System.GameStage):
		system = p_system
		target_stage = p_stage
	func execute() -> void:
		if system.game_stage != System.GameStage.NULL:
			var current_stage:Stage = system.game_stages[system.game_stage]
			if not current_stage.is_exit:
				current_stage.exit()
		if target_stage in system.game_stages:
			system.game_stage = target_stage
			var next_stage = system.game_stages[target_stage]
			next_stage.enter()
		complete()
