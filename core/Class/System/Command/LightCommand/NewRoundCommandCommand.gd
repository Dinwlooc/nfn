extends BehaviorCommand
class_name NewRoundCommand

class Context extends CommandContext:
	var new_round_player_id: int

## @param player_id          命令发起者玩家ID（通常为当前玩家）
## @param new_round_player_id 下一回合的玩家ID，若为 -1 则自动计算下一个座位玩家
## @param name_overriding     命令名称（可选）
## @param context_overriding  上下文（可选）
func _init(player_id: int, new_round_player_id: int = -1, name_overriding: StringName = &"NewRound", context_overriding: Context = Context.new()) -> void:
	super._init(player_id, name_overriding, context_overriding)
	_context.new_round_player_id = new_round_player_id

func execute(game_state: GameState) -> void:
	var target_id: int = _context.new_round_player_id
	if target_id == -1:
		var player_count: int = game_state.player_manager.get_player_count()
		if player_count == 0:
			complete()
			return
		var current_index:int = game_state.player_manager.get_seat_index_by_player_id(game_state.stage_manager.current_player_id)
		var next_index: int = (current_index + 1) % player_count
		var next_player: Player = game_state.player_manager.get_player_by_seat(next_index)
		if next_player == null:
			complete()
			return
		target_id = next_player.player_id
	game_state.start_new_round(target_id)
	complete()
