## 渲染上下文，核心管理类，负责：
## - 渲染区域的注册、查找与回调管理
## - RenderItem 对象池与实例映射
## - 拖拽状态管理
## - 提供创建/删除渲染区域的工厂接口
## 所有区域引用应通过 get_render_area() 实时获取，不应缓存。
## 区域与 RenderItem 的信号连接通过 connect_renderarea 建立，仅用于连接信号，不应持有区域引用。
extends RefCounted
class_name RenderContext

## 内部对象池，复用 RenderItem 实例，减少动态创建与回收开销。
class RenderItemPool extends RefCounted:
	var _pool: Array[RenderItem] = []
	## 最大缓存数量，超出时 item 将被释放而不是回池。
	const MAX_CACHE_SIZE = 20
	## 当池为空时创建新 item 时发出。
	signal item_created(item:RenderItem)
	## 从池中取出或新建一个 RenderItem，并用 item_data 初始化其数据。
	func create_item(item_data: TransPack) -> RenderItem:
		if not _pool.is_empty():
			var item: RenderItem = _pool.pop_back()
			item.data_update(item_data)
			return item
		else:
			var new_item:RenderItem = RenderItem.new(item_data)
			item_created.emit(new_item)
			return new_item
	## 回收 RenderItem。重置其状态，若池已满则直接释放节点。
	func recycle_item(item: RenderItem) -> void:
		item.reset()
		if _pool.size() >= MAX_CACHE_SIZE:
			item.queue_free()
			return
		_pool.append(item)

## 当前拖拽状态，包含被拖拽的卡牌及其所在区域。
class DragState:
	var area:RenderArea
	var card:RenderItem
## 公共区域的固定玩家ID，用于表示无特定归属的共享区域。
const PUBLIC_PLAYER_ID: int = 1
## 本地玩家ID（0 表示未设置），用于映射本地玩家区域到公共ID。
var local_player_id:int = 0
## 渲染区域注册表：第一层 key 为玩家ID，第二层 key 为区域名，值为 RenderArea 实例。
var _render_areas :Dictionary[int, Dictionary] = {}
## 区域创建回调表：第一层 key 为玩家ID，第二层 key 为区域名，值为回调数组。
## 当对应区域注册或已存在时，会调用这些回调，传入区域实例。
## 回调仅用于建立信号连接，不应在回调中持有区域引用。
var _callback_map: Dictionary[int, Dictionary] = {}
## RenderItem 实例映射：第一层 key 为 item_type（StringName），第二层 key 为 item_id（int），值为 RenderItem 实例。
var _item_mappings: Dictionary[StringName, Dictionary] = {}
## RenderItem 对象池实例。
var _item_pool: RenderItemPool = RenderItemPool.new()
## 当前拖拽状态，未拖拽时为 null。
var card_on_drag: DragState
## 操作管理器，用于处理用户操作。
var operation_manager: OperationManager

## 当渲染区域注册成功时发出。
signal render_area_registered(area_name: StringName, area: RenderArea, player_id: int)
## 当渲染区域注销时发出。
signal render_area_unregistered(area_name: StringName, player_id: int)
## 当通过 create_render_area 新创建区域时发出。
signal area_created(area: RenderArea, player_id: int)
## 开始拖拽卡牌时发出。
signal dragging_started(item: RenderItem)
## 取消拖拽卡牌时发出。
signal dragging_canceled(item: RenderItem)

func _init() -> void:
	# 内部连接：当新区域注册时，触发对应玩家/区域名的回调
	render_area_registered.connect(_on_render_area_registered)
## 区域注册信号的内部处理：遍历回调表并调用。
func _on_render_area_registered(area_name: StringName, area: RenderArea, player_id: int) -> void:
	if _callback_map.has(player_id) and _callback_map[player_id].has(area_name):
		for callback in _callback_map[player_id][area_name]:
			callback.call(area)
## 将传入的玩家ID映射为实际的字典 key。
## 如果本地玩家ID已设置，且传入ID等于本地玩家ID，则返回 PUBLIC_PLAYER_ID。
## 否则原样返回。
func _get_actual_player_id(player_id: int) -> int:
	if local_player_id == 0:
		return player_id
	if player_id == local_player_id:
		return PUBLIC_PLAYER_ID
	return player_id
## 注册区域创建回调。
## 若目标区域已经存在，立即用当前区域实例调用 callback。
## 仅用于连接信号等生命周期绑定操作，回调中不应缓存区域引用。
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
## 移除之前通过 connect_renderarea 注册的回调。
func disconnect_renderarea(area_name: StringName, callback: Callable, player_id: int = PUBLIC_PLAYER_ID) -> void:
	var actual_player_id: int = _get_actual_player_id(player_id)
	if _callback_map.has(actual_player_id) and _callback_map[actual_player_id].has(area_name):
		_callback_map[actual_player_id][area_name].erase(callback)
		if _callback_map[actual_player_id][area_name].is_empty():
			_callback_map[actual_player_id].erase(area_name)
			if _callback_map[actual_player_id].is_empty():
				_callback_map.erase(actual_player_id)
## 注册渲染区域。若默认玩家ID下已存在同名区域，且默认ID为公共ID且传入ID非公共ID，
## 则尝试使用传入ID直接注册。其他情况视为冲突并报错。
## 注意：区域销毁时会自动清理所有信号连接，此方法仅负责注册。
func register_render_area(area: RenderArea, player_id: int = PUBLIC_PLAYER_ID) -> void:
	var default_id: int = _get_actual_player_id(player_id)
	var area_name: StringName = area.get_area_name()
	# 卫语句：默认ID下未占用则直接注册
	if not _render_areas.has(default_id) or not _render_areas[default_id].has(area_name):
		if not _render_areas.has(default_id):
			_render_areas[default_id] = {}
		_render_areas[default_id][area_name] = area
		render_area_registered.emit(area_name, area, player_id)
		return
	# 若默认ID已被占用，且是公共ID且传入ID不为公共ID，则尝试使用传入ID注册
	if default_id == PUBLIC_PLAYER_ID and player_id != PUBLIC_PLAYER_ID:
		var alt_id: int = player_id
		if not _render_areas.has(alt_id) or not _render_areas[alt_id].has(area_name):
			if not _render_areas.has(alt_id):
				_render_areas[alt_id] = {}
			_render_areas[alt_id][area_name] = area
			render_area_registered.emit(area_name, area, player_id)
			return
	# 其他情况报错
	push_error("Duplicate area registration: " + area_name + " for player " + str(player_id))
## 注销渲染区域。移除字典条目并触发信号。
func unregister_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> void:
	var actual_player_id: int = _get_actual_player_id(player_id)
	if _render_areas.has(actual_player_id) and _render_areas[actual_player_id].erase(area_name):
		render_area_unregistered.emit(area_name, player_id)
		if _render_areas[actual_player_id].is_empty():
			_render_areas.erase(actual_player_id)
## 根据区域名和玩家ID获取区域实例（实时查询，不应缓存）。
func get_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> RenderArea:
	var actual_player_id: int = _get_actual_player_id(player_id)
	if _render_areas.has(actual_player_id):
		return _render_areas[actual_player_id].get(area_name)
	return null
## 获取所有已注册的玩家ID列表（包含公共ID）。
func get_all_player_ids() -> Array[int]:
	return _render_areas.keys()
## 获取指定玩家下的所有区域（名称到实例的字典）。
func get_player_areas(player_id: int = PUBLIC_PLAYER_ID) -> Dictionary[StringName, RenderArea]:
	var actual_player_id: int = _get_actual_player_id(player_id)
	return _render_areas.get(actual_player_id, {})
# ===== RenderItem 映射管理 =====
## 将 RenderItem 实例按其类型与ID注册到映射表中。
func register_render_item(item_type: StringName, item_id: int, render_item: RenderItem) -> void:
	if not _item_mappings.has(item_type):
		_item_mappings[item_type] = {}
	_item_mappings[item_type][item_id] = render_item
## 从映射表中移除指定类型的指定ID的 RenderItem。
func unregister_render_item(item_type: StringName, item_id: int) -> void:
	if _item_mappings.has(item_type) and _item_mappings[item_type].has(item_id):
		_item_mappings[item_type].erase(item_id)
## 通过类型和ID查找 RenderItem 实例。
func get_render_item_by_id(item_type: StringName, item_id: int) -> RenderItem:
	if _item_mappings.has(item_type):
		return _item_mappings[item_type].get(item_id)
	return null
# ===== 拖拽管理 =====
## 设置当前拖拽的卡牌，会先取消现有拖拽，标记卡牌为拖拽状态并触发信号。
func set_card_on_drag(area: RenderArea, realcard: RenderItem) -> void:
	remove_card_on_drag()
	card_on_drag = DragState.new()
	card_on_drag.area = area
	card_on_drag.card = realcard
	card_on_drag.card.dragged = true
	card_on_drag.area.tween_update(RenderEvent.new(RenderEvent.DefaultType.CARD_START_DRAGGING))
	dragging_started.emit(realcard)
## 取消当前拖拽，恢复卡牌状态并触发信号。
func remove_card_on_drag() -> void:
	if card_on_drag:
		var card = card_on_drag.card
		card_on_drag.card.dragged = false
		card_on_drag.area.tween_update(RenderEvent.new(RenderEvent.DefaultType.CARD_CANCEL_DRAGGING))
		dragging_canceled.emit(card)
		card_on_drag = null
## 获取当前拖拽卡牌所在的区域，无拖拽时返回 null。
func get_dragged_area() -> RenderArea:
	return card_on_drag.area if card_on_drag else null
## 获取当前拖拽的卡牌，无拖拽时返回 null。
func get_dragged_card() -> RenderItem:
	return card_on_drag.card if card_on_drag else null

# ===== 物品创建与回收 =====
## 根据 ItemPack 获取或新建 RenderItem，并自动注册映射。
func get_or_create_item(item_pack: ItemPack) -> RenderItem:
	var item = get_item(item_pack)
	if not item:
		item = _item_pool.create_item(item_pack)
		item.render_context = self
		register_render_item(item_pack.get_class_name(), item_pack.get_id(), item)
	return item
## 仅通过 ItemPack 查找已存在的 RenderItem，不创建。
func get_item(item_pack: ItemPack) ->RenderItem:
	return get_render_item_by_id(item_pack.get_class_name(), item_pack.get_id())

## 延迟回收 RenderItem（延迟到下一帧），自动处理取消映射与信号断开。
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
# ===== 区域生命周期管理 =====
## 直接销毁一个渲染区域，清空其所有子 RenderItem 并回池。
## 注意：不会撤销区域注册（需调用 unregister_render_area）。
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
## 移除渲染区域（注销 + 销毁）。
func remove_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> void:
	var area:RenderArea = get_render_area(area_name, player_id)
	if not area:
		push_warning("Attempted to remove non-existent render area: ", area_name, " for player ", player_id)
		return
	unregister_render_area(area_name, player_id)
	delete_render_area(area)
## 创建并注册渲染区域，使用 RenderAreaFactory 构造。
## 返回创建的实例，若构造失败返回 null。
func create_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> RenderArea:
	var area = RenderAreaFactory.create_area(area_name,player_id)
	if not area:
		return null
	register_render_area(area, player_id)
	area_created.emit(area, player_id)
	return area
## 设置操作管理器。
func set_operation_manager(manager: OperationManager) -> void:
	operation_manager = manager
## 获取操作管理器。
func get_operation_manager() -> OperationManager:
	return operation_manager
