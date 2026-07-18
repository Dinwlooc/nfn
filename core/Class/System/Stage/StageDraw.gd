extends Stage
class_name StageDraw

func _init() -> void:
	super._init()
	stage_name = &"Draw"

func enter(game_state: GameState, command_bus: CommandBus) -> void:
	super.enter(game_state, command_bus)
	var player_id: int = game_state.stage_manager.current_player_id
	var player: Player = game_state.player_manager.get_player_by_id(player_id)
	if not player:
		push_error("StageDraw: 未找到当前玩家")
		end_stage(game_state, command_bus)
		return
	var init_ap: int = player.get_attribute(&"init_AP")
	var reset_ap_command := ActionPointCommand.new(
		player,
		init_ap,
		ActionPointCommand.Context.Operation.SET,
		&"draw_stage_reset_ap"
	)
	var draw_count: int = player.get_attribute(&"draw_cards_count")
	var draw_event := DrawCardsCommand.new(player_id, draw_count)
	var callback: Callable = func(): end_stage(game_state, command_bus)
	command_bus.queue_behavior_with_callback(draw_event, callback)
	command_bus.queue_behavior(reset_ap_command)
