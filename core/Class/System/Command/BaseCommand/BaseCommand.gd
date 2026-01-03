extends RefCounted
class_name BaseCommand

signal event_completed
var is_completed: bool = false
var _player_id:int
var _event_name:StringName
# 标记事件完成并发出信号
func _init(name: StringName, init_player_id: int = -1):
	_event_name = name
	_player_id = init_player_id

func complete() -> void:
	is_completed = true
	event_completed.emit()
