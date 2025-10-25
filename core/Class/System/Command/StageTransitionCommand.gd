extends BehaviorCommand
class_name StageTransitionCommand

func _init():
	super._init(&"stage_transition")
func execute(system: System) -> void:
	var runtime_event = RuntimeStageTransitionCommand.new(system.stage_manager)
	runtime_event.execute()
	complete()

class RuntimeStageTransitionCommand extends AtomicCommand:
	var _stage_manager: StageManager
	func _init(p_stage_manager:StageManager):
		_stage_manager = p_stage_manager
	func execute() -> void:
		_stage_manager.call_deferred(&"start_round")
