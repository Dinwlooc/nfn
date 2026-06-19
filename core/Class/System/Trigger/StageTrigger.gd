## 阶段触发器：监听阶段完成与新一轮请求，生成对应的阶段推进命令。
extends SystemTrigger
class_name StageTrigger

var _system: System
var _stage_manager: StageManager

func _init(system: System) -> void:
	super(system)
	_system = system
	_stage_manager = system.game_state.stage_manager
	if _stage_manager:
		_stage_manager.stage_completed.connect(_on_stage_completed)
		_stage_manager.request_new_round.connect(_on_request_new_round)

func _on_stage_completed(ended_stage: Stage) -> void:
	var player_id: int = _stage_manager.current_player_id
	if ended_stage.is_temporary():
		var rollback_cmd := RollbackStageCommand.new(player_id, ended_stage)
		_system.command_processor.queue_behavior(rollback_cmd)
	else:
		var switch_cmd := SwitchMainStageCommand.new(player_id)
		_system.command_processor.queue_behavior(switch_cmd)

func _on_request_new_round(player_id: int) -> void:
	var new_round_cmd := NewRoundCommand.new(player_id)
	_system.command_processor.queue_behavior(new_round_cmd)
