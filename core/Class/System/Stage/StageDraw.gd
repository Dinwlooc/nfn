extends Stage
class_name StageDraw

func _init_expand() -> void:
	stage_name = &"Draw"
	time_limit = 0.5

func _on_all_completed() -> void:
	complete_stage()

func run()->void:
	var player_index = system.current_player_index
	var draw_count = system.player_manager.get_player_by_seat(player_index).draw_cards_count
	var draw_event = DrawCardsCommand.new(player_index, draw_count)
	command_processor.queue_behavior(draw_event)
	command_processor.all_completed.connect(_on_all_completed, CONNECT_ONE_SHOT)
