extends Control

func _ready()-> void:
	$ItemList_TestGame.item_selected.connect(_start_game)
	GlobalTransition.fade_out()
func _start_game(_index)-> void:
	GlobalTransition.change_scene_with_transition("res://core/tscn/game/main_game.tscn")
	pass
