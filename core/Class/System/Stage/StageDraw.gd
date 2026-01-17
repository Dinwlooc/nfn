extends Stage
class_name StageDraw

func _init(p_game_state: GameState) -> void:
	super._init(p_game_state)
	stage_name = &"Draw"
	time_limit = 0.0  # 设置为0表示不需要计时器

func run() -> void:
	var player_index = game_state.current_player_index
	var draw_count = game_state.player_manager.get_player_by_seat(player_index).get_attribute(&"draw_cards_count")
	var draw_event = DrawCardsCommand.new(player_index, draw_count)
	game_state.queue_behavior_with_callback(draw_event,_on_draw_completed)

func _on_draw_completed() -> void:
	end_stage()
