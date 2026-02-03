##管理RenderItem的渲染区域
extends RenderArea
class_name ItemRenderArea

var selected_items:Array[RenderItem] = []
var items_pool:Array[RenderItem] = []
var _divide_index:int = 0

func _ready() -> void:
	super._ready()
	_initialize_divide_index()

func _initialize_divide_index() -> void:
	var render_item_count := 0
	for child in get_children():
		if child is RenderItem:
			render_item_count += 1
	_divide_index = get_child_count() - render_item_count
	_validate_divide_index()

func _validate_divide_index() -> void:
	for i in range(_divide_index):
		var child = get_child(i)
		if child is RenderItem:
			push_warning("ItemRenderArea '%s' has RenderItem before divide index at position %d. This may cause rendering issues." % [name, i])

func _process_item_set(item_set: RenderRequest.ItemSet) -> void:
	if not render_context:
		push_error("RenderContext not set in RenderArea")
		return
	for item_pack in item_set.items:
		var render_item: RenderItem = render_context.get_or_create_item(item_pack)
		if render_item.area_name == area_name:
			_update_item_data(render_item, item_pack)
		else:
			var current_area = render_context.get_render_area(render_item.area_name)
			if current_area:
				current_area.remove_item(render_item)
			add_item(render_item)

func _connect_item_to_area(item:RenderItem) -> void:
	super._connect_item_to_area(item)
	item.request_drag.connect(on_drag)
	item.request_select.connect(on_select)

# 新增：内部断开连接方法
func _disconnect_item_from_area(item:RenderItem) -> void:
	super._disconnect_item_from_area(item)
	item.request_drag.disconnect(on_drag)
	item.request_select.disconnect(on_select)

func get_render_item_child_index() -> int:
	return _divide_index

# 选择操作
func on_select(item:RenderItem) -> void:
	if item.selected:
		item.selected = false
		selected_items.erase(item)
	else:
		if selected_items.size() >= select_limit:
			selected_items[0].selected = false
			selected_items.remove_at(0)
		item.selected = true
		selected_items.append(item)
	item.render_update()
	tween_update()
	selected.emit()

# 获取方法
func get_selected_items() -> Array[RenderItem]:
	return selected_items.duplicate()

func get_selected_ids() -> PackedInt32Array:
	var ids = PackedInt32Array()
	ids.resize(selected_items.size())
	for i in range(selected_items.size()):
		ids[i] = selected_items[i].get_id()
	return ids

func add_item(item:RenderItem, index:int = -1) -> void:
	if index < 0:
		index = items_pool.size()
	var tree_position = _divide_index + index
	if item.get_parent():
		item.get_parent().remove_child(item)
	add_child(item)
	move_child(item, tree_position)
	_connect_item_to_area(item)
	_set_item_to_pool(item, index)
# 修改：实现remove_item方法
func remove_item(item:RenderItem) -> void:
	if item.get_parent() == self:
		remove_child(item)
	var pool_id = item.pool_id
	if pool_id >= 0 and pool_id < items_pool.size() and items_pool[pool_id] == item:
		items_pool[pool_id] = null
		if item in selected_items:
			selected_items.erase(item)
		_compact_pool(pool_id, 1)
	if render_context and item.data:
		var item_type = item.data.get_class_name()
		var item_id = item.data.get_id()
		render_context.unregister_render_item(item_type, item_id)
	_disconnect_item_from_area(item)
	render_update()

func move_item_in_tree(item:RenderItem, new_pool_index:int) -> void:
	var current_tree_index = item.get_index()
	var target_tree_index = _divide_index + new_pool_index
	if current_tree_index != target_tree_index:
		move_child(item, target_tree_index)

# 数据池操作
func _set_item_to_pool(item:RenderItem, index:int) -> void:
	item.area_name = area_name
	if render_context:
		item.render_context = render_context
	item.pool_id = index
	if index >= items_pool.size():
		items_pool.append(item)
	else:
		items_pool[index] = item
	items_added.emit(item)
	render_update()

func _compact_pool(min_index:int, removed_count:int) -> void:
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
	render_update()

func _update_item_position(item:RenderItem, new_index:int) -> void:
	item.pool_id = new_index
	move_item_in_tree(item, new_index)
	if new_index >= items_pool.size():
		items_pool.append(item)
	else:
		items_pool[new_index] = item

# 移动操作
func move_item_to_index(current_pool_id:int, target_index:int, render_event:RenderEvent = RenderEvent.NULL_EVENT) -> void:
	var pool_size:int = items_pool.size()
	current_pool_id = clampi(current_pool_id, 0, pool_size - 1)
	target_index = clampi(target_index, 0, pool_size - 1)
	if current_pool_id == target_index:
		return
	var moved_item:RenderItem = items_pool[current_pool_id]
	var is_forward:bool = current_pool_id < target_index
	if is_forward:
		for i in range(current_pool_id + 1, target_index + 1):
			_update_item_position(items_pool[i], i - 1)
	else:
		for i in range(current_pool_id - 1, target_index - 1, -1):
			_update_item_position(items_pool[i], i + 1)
	_update_item_position(moved_item, target_index)
	tween_update(render_event)

func swap_items(pool_id_a:int, pool_id_b:int) -> void:
	var pool_size:int = items_pool.size()
	pool_id_a = clampi(pool_id_a, 0, pool_size - 1)
	pool_id_b = clampi(pool_id_b, 0, pool_size - 1)
	if pool_id_a == pool_id_b:
		return
	var item_a = items_pool[pool_id_a]
	var item_b = items_pool[pool_id_b]
	_update_item_position(item_a, pool_id_b)
	_update_item_position(item_b, pool_id_a)
	tween_update()

func get_item_count() -> int:
	return items_pool.size()

func get_item_by_index(index:int) -> RenderItem:
	if index >= 0 and index < items_pool.size():
		return items_pool[index]
	return null

func insert_non_render_item(node: Node, tree_index: int) -> bool:
	if node is RenderItem:
		push_error("Cannot insert RenderItem using this method. Use add_item instead.")
		return false
	if tree_index < 0 or tree_index > get_child_count():
		push_error("Invalid tree index: %d. Must be between 0 and %d." % [tree_index, get_child_count()])
		return false
	var render_item_start:int = _divide_index
	var render_item_end:int = _divide_index + items_pool.size()
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
		var actual_index:int = tree_index
		if actual_index > get_child_count():
			actual_index = get_child_count()
		if node.get_parent():
			node.get_parent().remove_child(node)
		add_child(node)
		move_child(node, actual_index)
	return true

func remove_non_render_item(node: Node) -> bool:
	if node is RenderItem:
		push_error("Cannot remove RenderItem using this method. Use remove_item instead.")
		return false
	if not is_instance_valid(node) or node.get_parent() != self:
		push_error("Node is not a child of this ItemRenderArea.")
		return false
	var node_index:int = node.get_index()
	remove_child(node)
	if node_index < _divide_index:
		_divide_index -= 1
	return true
