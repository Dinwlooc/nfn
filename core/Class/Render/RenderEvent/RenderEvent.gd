extends RefCounted
class_name RenderEvent

var type:String = DefaultType.NULL
var config:Dictionary[StringName,Variant]
static var NULL_EVENT = RenderEvent.new()
class DefaultType:
	const NULL = &"null"
	const INTO_AREA = &"into_area"
	const OUTTO_AREA = &"outto_area"
	const SELECT = &"select"

func _init(init_type:StringName = DefaultType.NULL) -> void:
	type = init_type

func set_config(new_config:Dictionary[StringName,Variant])->RenderEvent:
	config = new_config
	return self

func set_type(new_type:String)->RenderEvent:
	type = new_type
	return self
