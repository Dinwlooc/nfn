extends RefCounted
class_name RenderEvent

var config: Dictionary[StringName, Variant]
static var NULL_EVENT = RenderEvent.new()
class DefaultType:
	const NULL = &"null"
	const INTO_AREA = &"into_area"
	const OUTTO_AREA = &"outto_area"
	const SELECT = &"select"
	const DAMAGED = &"damaged"
	const SWAP_CARD = &"swap_card"
	const CARD_ADD = &"card_add"
	const CARD_REMOVE = &"card_remove"
	const CARD_SELECTION_CHANGED = &"card_selection_changed"
	const CARD_START_DRAGGING = &"card_start_dragging"
	const CARD_CANCEL_DRAGGING = &"card_cancel_dragging"
	const OPERATION_PLAY_CARD = &"operation_play_card"
	const OPERATION_DISCARD_CARDS = &"operation_discard_cards"
	const OPERATION_ABANDON_RESPONSE = &"operation_abandon_response"


func _init(initial_data: Variant = null) -> void:
	config = {}
	if initial_data is Dictionary:
		config = initial_data.duplicate()
	elif initial_data is StringName:
		config[&"type"] = initial_data
# 获取事件类型（从 config 中读取）
func get_type() -> StringName:
	return config.get(&"type", DefaultType.NULL)
# 设置事件类型（链式调用）
func set_type(new_type: StringName) -> RenderEvent:
	config[&"type"] = new_type
	return self

func merge_config(new_config:Dictionary[StringName,Variant])->RenderEvent:
	config.merge(new_config,true)
	return self
