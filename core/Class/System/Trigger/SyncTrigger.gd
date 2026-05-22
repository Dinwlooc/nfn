## 阶段同步触发器。
## 替代原有在命令中手动调用同步的方法，确保所有阶段进入事件（主阶段与临时阶段）均触发同步。
extends GameStateTrigger
class_name SyncTrigger

func _init(game_state: GameState) -> void:
	super._init(game_state)
	_game_state.stage_manager.stage_changed.connect(_on_stage_changed)

## 当任意阶段改变时（包括主阶段与临时阶段），发送阶段切换同步消息
func _on_stage_changed(old_stage: Stage, new_stage: Stage) -> void:
	RuleTrans.send_stage_switch_notify(_game_state)
