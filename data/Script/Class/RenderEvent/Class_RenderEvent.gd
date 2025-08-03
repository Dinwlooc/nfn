extends RefCounted
class_name RenderEvent

var type:DefaultType = DefaultType.NULL
var config:Dictionary
enum DefaultType {
	NULL,
	INTO_AREA,
	OUTTO_AREA,
	SELECT,
}

func _init(init_type:DefaultType = DefaultType.NULL) -> void:
	type = init_type

func set_config(new_config:Dictionary)->RenderEvent:
	config = new_config
	return self

func set_type(new_type:DefaultType)->RenderEvent:
	type = new_type
	return self
