extends RefCounted
class_name RenderContext

class DragState:
	var area:RenderArea
	var card:RenderItem
var _render_areas :Dictionary[StringName, RenderArea]= {}
signal render_area_registered(area_name: StringName, area: RenderArea)
signal render_area_unregistered(area_name: StringName)
var card_on_drag: DragState
signal dragged_update(is_card:bool)
var _callback_map: Dictionary[StringName, Array] = {}

func _init() -> void:
	# 连接信号到分发函数
	render_area_registered.connect(_on_render_area_registered)

# 区域注册时回调分发
func _on_render_area_registered(area_name: StringName, area: RenderArea) -> void:
	if _callback_map.has(area_name):
		for callback in _callback_map[area_name]:
			callback.call(area)

func connect_renderarea(area_name: StringName, callback: Callable) -> void:
	# 立即执行已注册区域
	if _render_areas.has(area_name):
		callback.call(_render_areas[area_name])
	if not _callback_map.has(area_name):
		_callback_map[area_name] = []
	if not _callback_map[area_name].has(callback):
		_callback_map[area_name].append(callback)
# 移除回调
func disconnect_renderarea(area_name: StringName, callback: Callable) -> void:
	if _callback_map.has(area_name):
		_callback_map[area_name].erase(callback)
		if _callback_map[area_name].is_empty():
			_callback_map.erase(area_name)

func register_render_area(area: RenderArea) -> void:
	assert(area.area_name != &"", "Area must have valid name")
	if _render_areas.has(area.area_name):
		push_error("Duplicate area registration: " + area.area_name)
		return
	_render_areas[area.area_name] = area
	render_area_registered.emit(area.area_name, area)

func unregister_render_area(area_name: StringName) -> void:
	if _render_areas.erase(area_name):
		render_area_unregistered.emit(area_name)

func get_render_area(area_name: StringName) -> RenderArea:
	return _render_areas.get(area_name)

func set_card_on_drag(area: RenderArea, realcard: RenderItem) -> void:
	remove_card_on_drag()
	card_on_drag = DragState.new()
	card_on_drag.area = area
	card_on_drag.card = realcard
	card_on_drag.card.dragged = true
	card_on_drag.area.tween_update()
	dragged_update.emit(true)

func remove_card_on_drag() -> void:
	if card_on_drag:
		card_on_drag.card.dragged = false
		card_on_drag.area.tween_update()
	card_on_drag = null
	dragged_update.emit(false)

func get_dragged_area() -> RenderArea:
	return card_on_drag.area if card_on_drag else null

func get_dragged_card() -> RenderItem:
	return card_on_drag.card if card_on_drag else null
