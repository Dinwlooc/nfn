## 管理RenderItem的渲染区域，继承自[RenderArea]。
## 负责维护区域内的渲染项列表、选择状态、树结构索引以及非渲染项的插入移除。
extends RenderArea
class_name ItemRenderArea

# ==================== 成员变量 ====================

## 当前选中的渲染项列表。
var selected_items: Array[RenderItem] = []
## 渲染项对象池，按索引顺序存储区域内的所有[RenderItem]。
var items_pool: Array[RenderItem] = []
## 树结构中非渲染项与渲染项的分割索引，索引位置之前的子节点为非[RenderItem]节点。
var _divide_index: int = 0

# ==================== 生命周期与初始化 ====================

func _ready() -> void:
	super._ready()
	_initialize_divide_index()

## 初始化分割索引[code]_divide_index[/code]，计算当前子节点中非[RenderItem]的数量。
func _initialize_divide_index() -> void:
	var render_item_count := 0
	for child in get_children():
		if child is RenderItem:
			render_item_count += 1
	_divide_index = get_child_count() - render_item_count
	_validate_divide_index()

## 验证分割索引之前的子节点中是否意外包含了[RenderItem]，若有则发出警告。
func _validate_divide_index() -> void:
	for i in range(_divide_index):
		var child = get_child(i)
		if child is RenderItem:
			push_warning("ItemRenderArea '%s' has RenderItem before divide index at position %d. This may cause rendering issues." % [name, i])

# ==================== 信号连接管理 ====================

## 重写父类方法，连接当前区域与[param item]的额外信号（拖拽、取消拖拽、选中）。
func _connect_item_to_area(item: RenderItem) -> void:
	super._connect_item_to_area(item)
	item.request_drag.connect(on_drag)
	item.request_cancel_dragged.connect(on_cancel_drag)
	item.request_select.connect(on_select)

## 断开当前区域与[param item]之间的所有信号连接。
func _disconnect_item_from_area(item: RenderItem) -> void:
	super._disconnect_item_from_area(item)
	if item.request_drag.is_connected(on_drag):
		item.request_drag.disconnect(on_drag)
	if item.request_select.is_connected(on_select):
		item.request_select.disconnect(on_select)
	if item.request_cancel_dragged.is_connected(on_cancel_drag):
		item.request_cancel_dragged.disconnect(on_cancel_drag)

# ==================== 核心逻辑处理 ====================

## 处理[param item_set]中的渲染项更新，从上下文获取或创建[RenderItem]，
## 并根据其所属区域进行添加、移除或数据更新。
func _process_item_set(item_set: RenderRequest.ItemSet) -> void:
	if not render_context:
		push_error("RenderContext not set in RenderArea")
		return
	for item_pack in item_set.items:
		var render_item: RenderItem = render_context.get_or_create_item(item_pack)
		if render_item.area_name == &"":
			var source_area: RenderArea = render_context.get_render_area(item_set.source_area_name, item_set.source_area_player_id)
			if source_area:
				source_area.item_created_for_removing.emit(render_item)
		if render_item.area_name == get_area_name():
			_update_item_data(render_item, item_pack)
		else:
			var current_area: RenderArea = render_context.get_render_area(render_item.area_name, render_item.player_id)
			if current_area:
				current_area.remove_item(render_item)
			add_item(render_item)

# ==================== 选择操作 ====================

## 处理[param item]的选中/取消选中逻辑，维护选中列表，并触发选择变化事件。
func on_select(item: RenderItem) -> void:
	if item.selected:
		item.selected = false
		item.render_update()
		if item.dragged:
			render_context.remove_card_on_drag()
		selected_items.erase(item)
	else:
		if selected_items.size() >= select_limit:
			selected_items[0].selected = false
			selected_items[0].render_update()
			selected_items.remove_at(0)
		item.selected = true
		selected_items.append(item)
	item.render_update()
	tween_update(RenderEvent.new().set_type(RenderEvent.DefaultType.CARD_SELECTION_CHANGED))
	selected.emit(item)

## 返回当前选中的[RenderItem]数组。
func get_selected_items() -> Array[RenderItem]:
	return selected_items

## 返回当前选中的[RenderItem]的ID紧缩数组。
func get_selected_ids() -> PackedInt32Array:
	var ids = PackedInt32Array()
	ids.resize(selected_items.size())
	for i in range(selected_items.size()):
		ids[i] = selected_items[i].get_id()
	return ids

# ==================== 添加与移除渲染项 ====================

## 向区域添加一个[param item]，可指定其在池中的[param index]（默认为末尾）。
func add_item(item: RenderItem, index: int = -1) -> void:
	if index < 0:
		index = items_pool.size()
	var tree_position = _divide_index + index
	if item.get_parent():
		item.position += item.get_parent().position
		item.get_parent().remove_child(item)
	item.position -= self.global_position
	add_child(item)
	move_child(item, tree_position)
	_connect_item_to_area(item)
	_set_item_to_pool(item, index)
	items_added.emit(item)
	render_update(RenderEvent.new(RenderEvent.DefaultType.CARD_ADD))

## 从区域移除[param item]，清理池中占位并断开信号连接。
func remove_item(item: RenderItem) -> void:
	if item.get_parent() == self:
		item.position = item.global_position
		remove_child(item)
	var pool_id: int = item.pool_id
	if pool_id >= 0 and pool_id < items_pool.size() and items_pool[pool_id] == item:
		items_pool[pool_id] = null
		if item in selected_items:
			selected_items.erase(item)
			item.selected = false
			item.render_update(RenderEvent.new(RenderEvent.DefaultType.CARD_REMOVE))
		_compact_pool(pool_id, 1)
	_disconnect_item_from_area(item)
	items_removed.emit(item)
	render_update(RenderEvent.new(RenderEvent.DefaultType.CARD_REMOVE))

## 仅移动[param item]在场景树中的位置，使其与池索引[param new_pool_index]保持一致。
func move_item_in_tree(item: RenderItem, new_pool_index: int) -> void:
	var current_tree_index = item.get_index()
	var target_tree_index = _divide_index + new_pool_index
	if current_tree_index != target_tree_index:
		move_child(item, target_tree_index)

# ==================== 内部池操作 ====================

## 将[param item]存入对象池的指定[param index]位置，同时更新其区域、玩家和池ID。
func _set_item_to_pool(item: RenderItem, index: int) -> void:
	item.area_name = get_area_name()
	item.player_id = player_id
	item.pool_id = index
	if index >= items_pool.size():
		items_pool.append(item)
	else:
		items_pool[index] = item

## 压缩对象池，从[param min_index]开始，移除[param removed_count]个空位，后续元素向前移动。
func _compact_pool(min_index: int, removed_count: int) -> void:
	if min_index + removed_count > items_pool.size():
		items_pool.resize(min_index)
		return
	var write_index = min_index
	for read_index in range(min_index + 1, items_pool.size()):
		var item = items_pool[read_index]
		if item == null:
			continue
		_update_item_position(item, write_index)
		items_pool[write_index] = item
		write_index += 1
	items_pool.resize(write_index)

## 更新[param item]在对象池中的位置为[param new_index]，并同步场景树中的移动。
func _update_item_position(item: RenderItem, new_index: int) -> void:
	item.pool_id = new_index
	move_item_in_tree(item, new_index)
	if new_index >= items_pool.size():
		items_pool.append(item)
	else:
		items_pool[new_index] = item

# ==================== 移动与交换操作 ====================

## 移动[param current_pool_id]处的项到[param target_index]，并触发补间更新（使用[param render_event]）。
func move_item_to_index(current_pool_id: int, target_index: int, render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	move_item_to_index_no_event(current_pool_id, target_index)
	tween_update(render_event)

## 交换[param pool_id_a]和[param pool_id_b]两个位置的项，并触发补间更新。
func swap_items(pool_id_a: int, pool_id_b: int) -> void:
	swap_items_no_event(pool_id_a, pool_id_b)
	tween_update()

## 移动项（不触发补间更新），将[param current_pool_id]处的项移动到[param target_index]。
func move_item_to_index_no_event(current_pool_id: int, target_index: int) -> void:
	var pool_size: int = items_pool.size()
	current_pool_id = clampi(current_pool_id, 0, pool_size - 1)
	target_index = clampi(target_index, 0, pool_size - 1)
	if current_pool_id == target_index:
		return
	var moved_item: RenderItem = items_pool[current_pool_id]
	var is_forward: bool = current_pool_id < target_index
	if is_forward:
		for i in range(current_pool_id + 1, target_index + 1):
			_update_item_position(items_pool[i], i - 1)
	else:
		for i in range(current_pool_id - 1, target_index - 1, -1):
			_update_item_position(items_pool[i], i + 1)
	_update_item_position(moved_item, target_index)

## 交换两个位置的项（不触发补间更新）。
func swap_items_no_event(pool_id_a: int, pool_id_b: int) -> void:
	var pool_size: int = items_pool.size()
	pool_id_a = clampi(pool_id_a, 0, pool_size - 1)
	pool_id_b = clampi(pool_id_b, 0, pool_size - 1)
	if pool_id_a == pool_id_b:
		return
	var item_a = items_pool[pool_id_a]
	var item_b = items_pool[pool_id_b]
	_update_item_position(item_a, pool_id_b)
	_update_item_position(item_b, pool_id_a)

## 完全重排渲染项顺序。根据[param target_ids]（长度需与池容量一致）将池内项一次性调整到位。
## [param item_type]为渲染项的类型名，用于从[RenderContext]查找项实例。
func rearrange_items(target_ids: PackedInt32Array, item_type: StringName) -> void:
	var pool: Array[RenderItem] = items_pool
	if pool.size() != target_ids.size():
		push_error("target_ids size mismatch in rearrange_items")
		return
	if not render_context:
		push_error("RenderContext not set in ItemRenderArea")
		return
	var n: int = target_ids.size()
	var i: int = 0
	var buf: RenderItem = null
	var hole: int = 0
	while i < n:
		var current: RenderItem = pool[i]
		if current and current.get_id() == target_ids[i]:
			i += 1
			continue
		buf = current
		hole = i
		while true:
			var target_id: int = target_ids[hole]
			var next_item: RenderItem = render_context.get_render_item_by_id(item_type, target_id)
			if next_item == buf:
				_update_item_position(buf, hole)
				break
			var old_pos: int = next_item.pool_id
			_update_item_position(next_item, hole)
			hole = old_pos
		i += 1
# ==================== 查询方法 ====================

## 返回对象池中的总项数。
func get_item_count() -> int:
	return items_pool.size()

## 根据[param index]获取对象池中的[RenderItem]，若索引无效则返回[code]null[/code]。
func get_item_by_index(index: int) -> RenderItem:
	if index >= 0 and index < items_pool.size():
		return items_pool[index]
	return null

## 返回分割索引[code]_divide_index[/code]，即树结构中非渲染项的数量。
func get_render_item_child_index() -> int:
	return _divide_index

# ==================== 非渲染项管理 ====================

## 在树结构的[param tree_index]处插入一个非[RenderItem]节点，自动维护分割索引。
## 若插入位置位于渲染项区间内会报错，并返回是否成功。
func insert_non_render_item(node: Node, tree_index: int) -> bool:
	if node is RenderItem:
		push_error("Cannot insert RenderItem using this method. Use add_item instead.")
		return false
	if tree_index < 0 or tree_index > get_child_count():
		push_error("Invalid tree index: %d. Must be between 0 and %d." % [tree_index, get_child_count()])
		return false
	var render_item_start: int = _divide_index
	var render_item_end: int = _divide_index + items_pool.size()
	if tree_index > render_item_start and tree_index < render_item_end:
		push_error("Cannot insert non-RenderItem between RenderItems. Index %d is between RenderItem indices %d and %d." %
				  [tree_index, render_item_start, render_item_end - 1])
		return false
	if tree_index <= _divide_index:
		_divide_index += 1
		if node.get_parent():
			node.get_parent().remove_child(node)
		add_child(node)
		move_child(node, tree_index)
	else:
		var actual_index: int = tree_index
		if actual_index > get_child_count():
			actual_index = get_child_count()
		if node.get_parent():
			node.get_parent().remove_child(node)
		add_child(node)
		move_child(node, actual_index)
	return true

## 从区域中移除一个非[RenderItem]节点，自动维护分割索引，并返回是否成功。
func remove_non_render_item(node: Node) -> bool:
	if node is RenderItem:
		push_error("Cannot remove RenderItem using this method. Use remove_item instead.")
		return false
	if not is_instance_valid(node) or node.get_parent() != self:
		push_error("Node is not a child of this ItemRenderArea.")
		return false
	var node_index: int = node.get_index()
	remove_child(node)
	if node_index < _divide_index:
		_divide_index -= 1
	return true
