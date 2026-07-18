## 阶段触发器：监听阶段完成、新回合请求、所有命令完成，生成对应的阶段调度命令
extends SystemTrigger
class_name StageTrigger

var _system: System

func _init(system: System) -> void:
	_system = system
	var _stage_manager: StageManager = system.game_state.stage_manager
	if _stage_manager:
		_stage_manager.stage_completed.connect(_on_stage_completed)
		_stage_manager.request_new_round.connect(_on_request_new_round)
		system.game_state.all_commands_completed.connect(_on_all_commands_completed)

func _on_stage_completed(ended_stage: Stage) -> void:
	if ended_stage.is_temporary():
		var rollback_cmd := StageScheduleCommand.new(
			_system.command_bus,
			StageScheduleCommand.Operation.ROLLBACK
		)
		_system.command_bus.queue_behavior(rollback_cmd)
	else:
		var switch_cmd := StageScheduleCommand.new(
			_system.command_bus,
			StageScheduleCommand.Operation.SWITCH_MAIN
		)
		_system.command_bus.queue_behavior(switch_cmd)

func _on_request_new_round(player_id: int) -> void:
	var game_state:GameState = _system.game_state
	var player_manager:PlayersManager = game_state.player_manager
	var player_count:int = player_manager.get_player_count()
	if player_count == 0:
		return
	var current_index:int = player_manager.get_seat_index_by_player_id(player_id)
	if current_index == -1:
		return
	var next_index:int = (current_index + 1) % player_count
	var next_player:Player = player_manager.get_player_by_seat(next_index)
	if not next_player:
		return
	var new_round_cmd := NewRoundCommand.new(_system.command_bus, next_player.get_id())
	_system.command_bus.queue_behavior(new_round_cmd)

func _on_all_commands_completed(_game_state:GameState) -> void:
	var stack:Array[Stage] = _system.game_state.stage_manager.temp_stage_stack
	if not stack.is_empty():
		var top_stage = stack[-1]
		if _system.game_state.stage_manager.current_stage != top_stage:
			var start_cmd := StageScheduleCommand.new(
				_system.command_bus,
				StageScheduleCommand.Operation.START_TEMP
			)
			_system.command_bus.queue_behavior(start_cmd)
			return
	var current:Stage = _system.game_state.stage_manager.current_stage
	if current and not current.is_ended and not current.is_paused:
		current.refresh_response(_system.game_state, _system.command_bus)
