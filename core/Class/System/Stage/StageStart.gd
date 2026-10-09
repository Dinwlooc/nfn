## 起始阶段：进入后立即请求结束当前阶段。
extends Stage
class_name StageStart

#== Constructor ==
func _init() -> void:
	super._init()
	stage_name = &"Start"

#== Public Methods ==
## 进入阶段
## @override @hook @no_escape @side_effect
func enter(game_state: GameState, command_bus: CommandBus) -> void:
	super.enter(game_state, command_bus)
	request_end_stage(command_bus)
