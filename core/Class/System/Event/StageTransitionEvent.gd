extends BehaviorEvent
class_name StageTransitionEvent

var target_stage: System.GameStage

func _init(p_target_stage: System.GameStage):
	super._init(&"stage_transition")
	target_stage = p_target_stage
	
func generate_runtime_event(system: System) -> RuntimeEvent:
	return RuntimeStageTransitionEvent.new(system, target_stage)

# 运行时阶段转换事件
class RuntimeStageTransitionEvent extends RuntimeEvent:
	var system: System
	var target_stage: System.GameStage
	func _init(p_system: System, p_stage: System.GameStage):
		system = p_system
		target_stage = p_stage
	func execute(_processor: EventProcessor) -> void:
		if system.game_stage != System.GameStage.NULL:
			var current = system.game_stages[system.game_stage]
			if !current.is_exit: current.exit()
		if target_stage in system.game_stages:
			system.game_stage = target_stage
			var next = system.game_stages[target_stage]
			next.enter()
		complete()
