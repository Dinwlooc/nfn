## @param command_bus 命令总线引用（必须）
## @param new_round_player_id 下一回合的玩家ID，若为 -1 则自动计算下一个座位玩家
extends ScheduleCommand
class_name NewRoundCommand

class Context extends CommandContext:
	var new_round_player_id: int

func _init(
	command_bus: CommandBus,
	new_round_player_id: int = -1,
	name_overriding: StringName = &"NewRound",
	context_overriding: Context = Context.new()
) -> void:
	super._init(command_bus, name_overriding, context_overriding)
	var ctx = _context as Context
	ctx.new_round_player_id = new_round_player_id

func execute(game_state: GameState) -> void:
	var ctx = _context as Context
	var target_id: int = ctx.new_round_player_id
	if target_id == -1:
		var player_count: int = game_state.player_manager.get_player_count()
		if player_count == 0:
			complete()
			return
		var current_index: int = game_state.player_manager.get_seat_index_by_player_id(game_state.stage_manager.current_player_id)
		var next_index: int = (current_index + 1) % player_count
		var next_player: Player = game_state.player_manager.get_player_by_seat(next_index)
		if next_player == null:
			complete()
			return
		target_id = next_player.get_id()
	game_state.stage_manager.start_round(target_id, game_state, _command_bus)
	complete()
