extends RefCounted
class_name BaseEvent

var event_type:int
var player_id:int

func _init(init_type:int,init_player_id:int = GlobalServer.get_id()) -> void:
	event_type = init_type
	player_id = init_player_id
