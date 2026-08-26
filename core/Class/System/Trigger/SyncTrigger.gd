extends GameStateTrigger
class_name SyncTrigger

func _init(game_state: GameState, command_bus: CommandBus) -> void:
	super._init(game_state, command_bus)
	_game_state.stage_manager.stage_changed.connect(_on_stage_changed)
## @signal-listener 阶段切换时发送同步通知
func _on_stage_changed(old_stage: Stage, new_stage: Stage) -> void:
	RuleTrans.send_stage_switch_notify(_game_state)
##
func disconnect_all() -> void:
	_game_state.stage_manager.stage_changed.disconnect(_on_stage_changed)
