extends RefCounted
class_name RenderContext

class RenderItemPool:
	var _pool: Array[RenderItem] = []
	signal item_created(item:RenderItem)
	func create_item(item_data: TransPack) -> RenderItem:
		if not _pool.is_empty():
			var item: RenderItem = _pool.pop_back()
			item.data_update(item_data)  # 重置状态
			return item
		else:
			var new_item:RenderItem = RenderItem.new(item_data)
			item_created.emit(new_item)
			return new_item
	func recycle_item(item: RenderItem) -> void:
		item.reset()
		_pool.append(item)

class DragState:
	var area:RenderArea
	var card:RenderItem

var loacal_player_id:int = 0
var _render_areas :Dictionary[StringName, RenderArea]= {}
var _callback_map: Dictionary[StringName, Array] = {}
var _item_mappings: Dictionary[StringName, Dictionary] = {}
var _item_pool: RenderItemPool = RenderItemPool.new()
var card_on_drag: DragState

signal render_area_registered(area_name: StringName, area: RenderArea)
signal render_area_unregistered(area_name: StringName)
signal dragged_update(is_card:bool)



func _init() -> void:
	render_area_registered.connect(_on_render_area_registered)

func _on_render_area_registered(area_name: StringName, area: RenderArea) -> void:
	if _callback_map.has(area_name):
		for callback in _callback_map[area_name]:
			callback.call(area)

func connect_renderarea(area_name: StringName, callback: Callable) -> void:
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

# 新增：管理RenderItem映射的方法
func register_render_item(item_type: StringName, item_id: int, render_item: RenderItem) -> void:
	if not _item_mappings.has(item_type):
		_item_mappings[item_type] = {}
	_item_mappings[item_type][item_id] = render_item

func unregister_render_item(item_type: StringName, item_id: int) -> void:
	if _item_mappings.has(item_type) and _item_mappings[item_type].has(item_id):
		_item_mappings[item_type].erase(item_id)

func get_render_item_by_id(item_type: StringName, item_id: int) -> RenderItem:
	if _item_mappings.has(item_type):
		return _item_mappings[item_type].get(item_id)
	return null

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

# 创建或获取项目
func get_or_create_item(item_pack: ItemPack) -> RenderItem:
	var item = get_render_item_by_id(item_pack.get_class_name(), item_pack.get_id())
	if not item:
		item = _item_pool.create_item(item_pack)
		register_render_item(item_pack.get_class_name(), item_pack.get_id(), item)
	return item

# 延迟回收请求
func request_recycle_item(item: RenderItem) -> void:
	call_deferred("_recycle_item_deferred", item)

func _recycle_item_deferred(item: RenderItem) -> void:
	if item.data:
		var item_type = item.data.get_class_name()
		var item_id = item.data.get_id()
		unregister_render_item(item_type, item_id)
	if item.area_name:
		var current_area = get_render_area(item.area_name)
		if current_area:
			current_area._disconnect_item_from_area(item)
	_item_pool.recycle_item(item)
