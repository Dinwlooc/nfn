extends Stage
class_name StageDraw

func _init_expand() -> void:
	time_limit = 0.5

func enter_expand() -> void:
	var player_index = system.current_player_index
	var draw_count = system.alive_players[player_index].draw_cards_count
	var draw_event = DrawCardsEvent.new(player_index, draw_count)
	event_processor.queue_behavior(draw_event)
	event_processor.all_completed.connect(_on_all_completed, CONNECT_ONE_SHOT)
	
func _on_all_completed() -> void:
	complete_stage()
