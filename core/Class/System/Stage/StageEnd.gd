## 结束阶段：进入后立即请求结束当前阶段。
extends Stage
class_name StageEnd

#== Constructor ==
func _init() -> void:
	super._init()
	stage_name = &"End"
	time_limit = 0.0

#== Public Methods ==
## 进入阶段
## @override @hook @stack_local @side_effect
func enter(game_state: GameState, command_bus: CommandBus) -> void:
	super.enter(game_state, command_bus)
	request_end_stage(command_bus)
