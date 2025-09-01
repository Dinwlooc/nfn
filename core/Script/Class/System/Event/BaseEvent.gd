extends RefCounted
class_name BaseEvent

enum EventType { BEHAVIOR, RUNTIME }
signal event_completed

var event_type: int
var event_name: StringName
var player_id: int = -1
var is_completed: bool = false

func _init(init_type: int, init_name: StringName, init_player_id: int = -1) -> void:
	event_type = init_type
	event_name = init_name
	player_id = init_player_id

# 标记事件完成并发出信号
func complete() -> void:
	is_completed = true
	event_completed.emit()
