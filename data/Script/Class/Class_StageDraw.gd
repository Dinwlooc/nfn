extends Stage
class_name StageDraw

func enter_expand()->void:
	draw_cards(system.alive_players[system.current_player_index].get_attribute("NCD"))
	pass
