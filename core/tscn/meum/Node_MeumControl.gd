extends Control

## 菜单就绪：连接选项点击并播放淡出
func _ready()-> void:
	$ItemList_TestGame.item_selected.connect(_start_game)
	GlobalTransition.fade_out()
## 选项被选中：带转场进入主场景
func _start_game(_index)-> void:
	GlobalTransition.change_scene_with_transition("res://core/tscn/game/main_game.tscn")
	pass
