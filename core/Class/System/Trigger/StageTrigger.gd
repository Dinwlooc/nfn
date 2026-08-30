extends SystemTrigger
class_name StageTrigger
func _init(system: System) -> void:
	super._init(system)
	var _stage_manager: StageManager = system.game_state.stage_manager
	if _stage_manager:
		_stage_manager.stage_completed.connect(_on_stage_completed)
		_stage_manager.request_new_round.connect(_on_request_new_round)
		system.game_state.all_commands_completed.connect(_on_all_commands_completed)
## @signal_listener 阶段完成：临时阶段回滚，否则切主阶段
func _on_stage_completed(ended_stage: Stage) -> void:
	if ended_stage.is_temporary():
		var rollback_cmd := StageScheduleCommand.new(
			_system.command_bus,StageScheduleCommand.Operation.ROLLBACK
		)
		_system.command_bus.queue_behavior(rollback_cmd)
		return
	var switch_cmd := StageScheduleCommand.new(
		_system.command_bus,StageScheduleCommand.Operation.SWITCH_MAIN
	)
	_system.command_bus.queue_behavior(switch_cmd)
## @signal_listener 请求新回合
func _on_request_new_round(player_id: int) -> void:
	var game_state: GameState = _system.game_state
	var player_manager: PlayersManager = game_state.player_manager
	var player_count: int = player_manager.get_player_count()
	if player_count == 0:
		return
	var current_index: int = player_manager.get_seat_index_by_player_id(player_id)
	if current_index == -1:
		return
	var next_index: int = (current_index + 1) % player_count
	var next_player: Player = player_manager.get_player_by_seat(next_index)
	if not next_player:
		return
	var new_round_cmd := NewRoundCommand.new(_system.command_bus, next_player.get_id())
	_system.command_bus.queue_behavior(new_round_cmd)
## @signal_listener 所有命令完成后恢复或刷新阶段
func _on_all_commands_completed(_game_state: GameState) -> void:
	var stack: Array[Stage] = _system.game_state.stage_manager.temp_stage_stack
	if not stack.is_empty():
		var top_stage = stack[-1]
		if _system.game_state.stage_manager.current_stage != top_stage:
			var start_cmd := StageScheduleCommand.new(
				_system.command_bus,
				StageScheduleCommand.Operation.START_TEMP
			)
			_system.command_bus.queue_behavior(start_cmd)
			return
	var current: Stage = _system.game_state.stage_manager.current_stage
	if current and not current.is_ended and not current.is_paused:
		current.refresh_response(_system.game_state, _system.command_bus)
##
func disconnect_all() -> void:
	var _stage_manager: StageManager = _system.game_state.stage_manager
	if _stage_manager:
		_stage_manager.stage_completed.disconnect(_on_stage_completed)
		_stage_manager.request_new_round.disconnect(_on_request_new_round)
	_system.game_state.all_commands_completed.disconnect(_on_all_commands_completed)
