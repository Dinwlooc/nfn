extends Control

func _ready()-> void:
	$ItemList_TestGame.connect("item_selected",_start_game)
	$Transition.connect("OK",transition)
func _start_game(_index)-> void:
	$Transition.outto()
	pass

func transition():
	get_tree().change_scene_to_file("res://tscn/main_game.tscn")
