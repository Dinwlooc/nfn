extends Stage
class_name StageDraw

func _init() -> void:
	super._init()
	stage_name = &"Draw"
	time_limit = 0.0

func enter(game_state: GameState) -> void:
	super.enter(game_state)
	var player_index = game_state.current_player_index
	var draw_count = game_state.player_manager.get_player_by_seat(player_index).get_attribute(&"draw_cards_count")
	var draw_event = DrawCardsCommand.new(player_index, draw_count)
	var callback:Callable = func(): end_stage(game_state)
	game_state.queue_behavior_with_callback(draw_event, callback)
