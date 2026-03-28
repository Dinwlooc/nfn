extends RefCounted
class_name RenderContext

class RenderItemPool extends RefCounted:
	var _pool: Array[RenderItem] = []
	const MAX_CACHE_SIZE = 20
	signal item_created(item:RenderItem)
	func create_item(item_data: TransPack) -> RenderItem:
		if not _pool.is_empty():
			var item: RenderItem = _pool.pop_back()
			item.data_update(item_data)
			return item
		else:
			var new_item:RenderItem = RenderItem.new(item_data)
			item_created.emit(new_item)
			return new_item
	func recycle_item(item: RenderItem) -> void:
		item.reset()
		if _pool.size() >= MAX_CACHE_SIZE:
			item.queue_free()
			return
		_pool.append(item)

class DragState:
	var area:RenderArea
	var card:RenderItem

##公共区域的玩家ID
const PUBLIC_PLAYER_ID: int = -1
var local_player_id:int = -1
##第一层为玩家ID，第二层为区域名到RenderArea的映射
var _render_areas :Dictionary[int, Dictionary] = {}
##第一层为玩家ID，第二层为区域名到回调数组的映射
var _callback_map: Dictionary[int, Dictionary] = {}
var _item_mappings: Dictionary[StringName, Dictionary] = {}
var _item_pool: RenderItemPool = RenderItemPool.new()
var card_on_drag: DragState
var operation_manager: OperationManager
signal render_area_registered(area_name: StringName, area: RenderArea, player_id: int)
signal render_area_unregistered(area_name: StringName, player_id: int)
signal area_created(area: RenderArea, player_id: int)
signal dragging_started(item: RenderItem)   # 新增
signal dragging_canceled(item: RenderItem)  # 新增

func _init() -> void:
	render_area_registered.connect(_on_render_area_registered)

func _on_render_area_registered(area_name: StringName, area: RenderArea, player_id: int) -> void:
	if _callback_map.has(player_id) and _callback_map[player_id].has(area_name):
		for callback in _callback_map[player_id][area_name]:
			callback.call(area)

# 获取实际的玩家ID用于字典访问
func _get_actual_player_id(player_id: int) -> int:
	if local_player_id == -1:
		return PUBLIC_PLAYER_ID
	if player_id == local_player_id:
		return PUBLIC_PLAYER_ID
	return player_id

func connect_renderarea(area_name: StringName, callback: Callable, player_id: int = PUBLIC_PLAYER_ID) -> void:
	var actual_player_id: int = _get_actual_player_id(player_id)
	if _render_areas.has(actual_player_id) and _render_areas[actual_player_id].has(area_name):
		callback.call(_render_areas[actual_player_id][area_name])
	if not _callback_map.has(actual_player_id):
		_callback_map[actual_player_id] = {}
	if not _callback_map[actual_player_id].has(area_name):
		_callback_map[actual_player_id][area_name] = []
	if not _callback_map[actual_player_id][area_name].has(callback):
		_callback_map[actual_player_id][area_name].append(callback)

# 移除回调
func disconnect_renderarea(area_name: StringName, callback: Callable, player_id: int = PUBLIC_PLAYER_ID) -> void:
	var actual_player_id: int = _get_actual_player_id(player_id)

	if _callback_map.has(actual_player_id) and _callback_map[actual_player_id].has(area_name):
		_callback_map[actual_player_id][area_name].erase(callback)
		if _callback_map[actual_player_id][area_name].is_empty():
			_callback_map[actual_player_id].erase(area_name)
			if _callback_map[actual_player_id].is_empty():
				_callback_map.erase(actual_player_id)

func register_render_area(area: RenderArea, player_id: int = PUBLIC_PLAYER_ID) -> void:
	var actual_player_id: int = _get_actual_player_id(player_id)
	if not _render_areas.has(actual_player_id):
		_render_areas[actual_player_id] = {}
	if _render_areas[actual_player_id].has(area.get_area_name()):
		push_error("Duplicate area registration: " + area.get_area_name() + " for player " + str(player_id))
		return
	_render_areas[actual_player_id][area.get_area_name()] = area
	render_area_registered.emit(area.get_area_name(), area, player_id)

func unregister_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> void:
	var actual_player_id: int = _get_actual_player_id(player_id)
	if _render_areas.has(actual_player_id) and _render_areas[actual_player_id].erase(area_name):
		render_area_unregistered.emit(area_name, player_id)
		if _render_areas[actual_player_id].is_empty():
			_render_areas.erase(actual_player_id)

func get_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> RenderArea:
	var actual_player_id: int = _get_actual_player_id(player_id)
	if _render_areas.has(actual_player_id):
		return _render_areas[actual_player_id].get(area_name)
	return null

# 获取所有玩家ID（包括公共ID）
func get_all_player_ids() -> Array[int]:
	return _render_areas.keys()

# 获取指定玩家的所有区域
func get_player_areas(player_id: int = PUBLIC_PLAYER_ID) -> Dictionary[StringName, RenderArea]:
	var actual_player_id: int = _get_actual_player_id(player_id)
	return _render_areas.get(actual_player_id, {})

# 管理RenderItem映射
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
	card_on_drag.area.tween_update(RenderEvent.new(RenderEvent.DefaultType.CARD_START_DRAGGING))
	dragging_started.emit(realcard)

func remove_card_on_drag() -> void:
	if card_on_drag:
		var card = card_on_drag.card
		card_on_drag.card.dragged = false
		card_on_drag.area.tween_update(RenderEvent.new(RenderEvent.DefaultType.CARD_CANCEL_DRAGGING))
		dragging_canceled.emit(card)
		card_on_drag = null

func get_dragged_area() -> RenderArea:
	return card_on_drag.area if card_on_drag else null

func get_dragged_card() -> RenderItem:
	return card_on_drag.card if card_on_drag else null

# 创建或获取项目
func get_or_create_item(item_pack: ItemPack) -> RenderItem:
	var item = get_render_item_by_id(item_pack.get_class_name(), item_pack.get_id())
	if not item:
		item = _item_pool.create_item(item_pack)
		item.render_context = self
		register_render_item(item_pack.get_class_name(), item_pack.get_id(), item)
	return item

# 延迟回收请求
func request_recycle_item(item: RenderItem) -> void:
	call_deferred(&"_recycle_item_deferred", item)

func _recycle_item_deferred(item: RenderItem) -> void:
	if item.data:
		var item_type = item.data.get_class_name()
		var item_id = item.data.get_id()
		unregister_render_item(item_type, item_id)
	if item.area_name:
		for player_id in _render_areas:
			var areas:Dictionary = _render_areas[player_id]
			if areas.has(item.area_name):
				var current_area:RenderArea = areas[item.area_name]
				if current_area:
					current_area._disconnect_item_from_area(item)
				break
	_item_pool.recycle_item(item)

## 自动回收RenderItem。不会撤销注册。
func delete_render_area(area: RenderArea) -> void:
	if card_on_drag:
		if card_on_drag.area == area:
			remove_card_on_drag()
		else:
			var dragged_card = card_on_drag.card
			if dragged_card and dragged_card.get_parent() == area:
				remove_card_on_drag()
	for child in area.get_children():
		if child is not RenderItem:
			continue
		var item: RenderItem = child
		area.remove_child(item)
		if item.data:
			var item_type = item.data.get_class_name()
			var item_id = item.data.get_id()
			unregister_render_item(item_type, item_id)
		area._disconnect_item_from_area(item)
		_item_pool.recycle_item(item)
	area.queue_free()

func remove_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> void:
	var area:RenderArea = get_render_area(area_name, player_id)
	if not area:
		push_warning("Attempted to remove non-existent render area: ", area_name, " for player ", player_id)
		return
	unregister_render_area(area_name, player_id)
	delete_render_area(area)

## 创建并注册渲染区域
func create_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> RenderArea:
	var area = RenderAreaFactory.create_area(area_name,player_id)
	if not area:
		return null
	register_render_area(area, player_id)
	area_created.emit(area, player_id)
	return area

func set_operation_manager(manager: OperationManager) -> void:
	operation_manager = manager

func get_operation_manager() -> OperationManager:
	return operation_manager
