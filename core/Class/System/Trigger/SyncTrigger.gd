extends GameStateTrigger
class_name SyncTrigger

## 构造：连接阶段变更信号
func _init(game_state: GameState, command_bus: CommandBus) -> void:
	super._init(game_state, command_bus)
	_game_state.stage_manager.stage_changed.connect(_on_stage_changed)
## @signal_listener 阶段切换时发送阶段集合
func _on_stage_changed(_old_stage: Stage, new_stage: Stage) -> void:
	RuleTrans.send_stage_set(_game_state, new_stage)
##
func disconnect_all() -> void:
	_game_state.stage_manager.stage_changed.disconnect(_on_stage_changed)
