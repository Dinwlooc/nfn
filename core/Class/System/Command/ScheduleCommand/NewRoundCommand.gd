## 新回合命令：切换到下一个玩家或指定ID
extends ScheduleCommand
class_name NewRoundCommand

## @context
class Context extends CommandContext:
	var new_round_player_id: int = -1

## @seam_override
func _init(
	command_bus: CommandBus,
	new_round_player_id: int = -1,
	name_overriding: StringName = &"NewRound",
	context_overriding: Context = Context.new()
) -> void:
	super._init(command_bus, name_overriding, context_overriding)
	context_overriding.new_round_player_id = new_round_player_id

## 静态执行：计算下一个玩家ID并启动新回合
static func do_execute(context: Context, game_state: GameState, command_bus: CommandBus) -> void:
	var target_id: int = context.new_round_player_id
	if target_id == -1:
		var player_count: int = game_state.player_manager.get_player_count()
		if player_count == 0:
			return
		var current_index: int = game_state.player_manager.get_seat_index_by_player_id(game_state.stage_manager.current_player_id)
		var next_index: int = (current_index + 1) % player_count
		var next_player: Player = game_state.player_manager.get_player_by_seat(next_index)
		if next_player == null:
			return
		target_id = next_player.get_id()
	game_state.stage_manager.start_round(target_id, game_state, command_bus)

## @hook
func execute(game_state: GameState) -> void:
	if _context.is_cancelled:
		complete()
		return
	if _context.is_virtual:
		complete()
		return
	var ctx: Context = _context
	do_execute(ctx, game_state, _command_bus)
	complete()
