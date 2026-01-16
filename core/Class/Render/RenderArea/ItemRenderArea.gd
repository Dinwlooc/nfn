##管理RenderItem的渲染区域
extends RenderArea
class_name ItemRenderArea

var items_pool:Array[RenderItem] = []
var item_id_to_instance:Dictionary[int, RenderItem] = {}
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

func get_render_item_child_index() -> int:
	return _divide_index

func add_item(item:RenderItem, index:int = -1) -> void:
	if index < 0:
		index = items_pool.size()
	var tree_position = _divide_index + index
	if item.get_parent():
		item.get_parent().remove_child(item)
	add_child(item)
	move_child(item, tree_position)
	_set_item_to_pool(item, index)

func remove_item(item:RenderItem) -> void:
	if item.get_parent() == self:
		remove_child(item)

func remove_items_by_uids(uids:PackedInt32Array) -> Array[RenderItem]:
	var removed_items:Array[RenderItem] = []
	var min_index := -1
	for uid in uids:
		if item_id_to_instance.has(uid):
			var item = item_id_to_instance[uid]
			removed_items.append(item)
			var pool_id = item.pool_id
			if min_index == -1 or pool_id < min_index:
				min_index = pool_id
			if item in selected_items:
				selected_items.erase(item)
			item_id_to_instance.erase(uid)
			items_pool[pool_id] = null
			remove_item(item)
	if min_index != -1:
		_compact_pool(min_index, uids.size())
	return removed_items

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
	item_id_to_instance[item.get_id()] = item
	if index >= items_pool.size():
		items_pool.append(item)
	else:
		items_pool[index] = item
	items_added.emit(item)

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
	item_move_requested.emit(item, new_index, self)

# 移动操作
func move_item_to_index(current_pool_id:int, target_index:int, render_event:RenderEvent = RenderEvent.new()) -> void:
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

func get_item_by_uid(uid:int) -> RenderItem:
	return item_id_to_instance.get(uid)

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
