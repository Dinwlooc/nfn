extends Stage
class_name StageDraw

func _init_expand()->void:
	time_limit = 0.5
	pass

func enter_expand()->void:
	draw_cards(system.alive_players[system.current_player_index].get_attribute("NCD"))
	pass
