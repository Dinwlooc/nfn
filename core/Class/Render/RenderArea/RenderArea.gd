extends Control
class_name RenderArea
# 总控区域渲染与交互

signal render_requested(render_event:RenderEvent)
signal tween_requested(render_event:RenderEvent)
signal selected()
signal items_add_requested(items:Array[TransPack], area:RenderArea)
signal items_added(item:RenderItem)
signal items_remove_requested(uids:PackedInt32Array, area:RenderArea)
signal item_move_requested(item:RenderItem, new_index:int, area:RenderArea)
signal context_ready()

var area_name:StringName
var items_pool:Array[RenderItem] = []
@export var item_id_to_instance:Dictionary[int, RenderItem] = {}
var selected_items:Array[RenderItem] = []
var select_limit:int = 1
var _divide_index:int = 0
var render_context:RenderContext
class DefaultArea:
	const HAND:StringName = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.HAND]
	const PLAYERS:StringName = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.PLAYERS]
	const STAGE:StringName = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.STAGE]

func _ready() -> void:
	_initialize_divide_index()
	ready_expand()

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
			push_warning("RenderArea '%s' has RenderItem before divide index at position %d. This may cause rendering issues." % [name, i])

func ready_expand() -> void:
	pass

func process_request(request: RenderRequest) -> void:
	pass

func _exit_tree() -> void:
	if render_context:
		render_context.unregister_render_area(area_name)

func get_render_item_child_index() -> int:
	return _divide_index

func add_render_item_child(item:RenderItem, index:int = -1) -> void:
	if index < 0:
		index = items_pool.size()
	var tree_position = _divide_index + index
	if item.get_parent():
		item.get_parent().remove_child(item)
	add_child(item)
	move_child(item, tree_position)
	_set_item_to_pool(item, index)

func remove_render_item_child(item:RenderItem) -> void:
	if item.get_parent() == self:
		remove_child(item)

func move_render_item_in_tree(item:RenderItem, new_pool_index:int) -> void:
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
			remove_render_item_child(item)
	if min_index != -1:
		_compact_pool(min_index, uids.size())
	return removed_items

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
	move_render_item_in_tree(item, new_index)
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
	tween_update()
	selected.emit()

func on_drag(pool_id:int) -> void:
	if not render_context:
		return
	if Input.get_mouse_button_mask() == 1:
		render_context.set_card_on_drag(self, items_pool[pool_id])
	else:
		render_context.remove_card_on_drag()

# 获取方法
func get_selected_items() -> Array[RenderItem]:
	return selected_items.duplicate()

func get_selected_ids() -> PackedInt32Array:
	var ids = PackedInt32Array()
	ids.resize(selected_items.size())
	for i in range(selected_items.size()):
		ids[i] = selected_items[i].get_id()
	return ids

# 渲染方法
func render_update(render_event:RenderEvent = RenderEvent.new()) -> void:
	render_requested.emit(render_event)

func tween_update(render_event:RenderEvent = RenderEvent.new()) -> void:
	tween_requested.emit(render_event)

# 上下文管理
func set_render_context(context:RenderContext) -> void:
	render_context = context
	if render_context.dragged_update.is_connected(tween_update.unbind(1)):
		render_context.dragged_update.disconnect(tween_update)
	render_context.dragged_update.connect(tween_update.unbind(1))
	for item in items_pool:
		if item != null:
			item.render_context = context

func compact_pool(min_index: int, removed_count: int) -> void:
	if min_index + removed_count > items_pool.size():
		items_pool.resize(min_index)
		return
	var write_index = min_index
	for read_index in range(min_index + 1, items_pool.size()):
		var card = items_pool[read_index]
		if card == null:
			continue
		update_card_position(card, write_index)
		items_pool[write_index] = card
		write_index += 1
	items_pool.resize(write_index)
	render_update()

func update_card_position(item: RenderItem, new_index: int) -> void:
	item.pool_id = new_index
	if new_index >= items_pool.size():
		items_pool.append(item)
	else:
		items_pool[new_index] = item
	item_move_requested.emit(item, new_index,self)
# 移动卡片
func move_card_to_index(current_pool_id: int, target_index: int, render_event: RenderEvent = RenderEvent.new()) -> void:
	var pool_size: int = items_pool.size()
	current_pool_id = clampi(current_pool_id, 0, pool_size - 1)
	target_index = clampi(target_index, 0, pool_size - 1)
	if current_pool_id == target_index:
		return
	var moved_card: RenderItem = items_pool[current_pool_id]
	var is_forward: bool = current_pool_id < target_index
	var start_index: int
	var end_index: int
	if is_forward:
		start_index = current_pool_id + 1
		end_index = target_index
		for i in range(start_index, end_index + 1):
			update_card_position(items_pool[i], i - 1)
	else:
		start_index = current_pool_id - 1
		end_index = target_index
		for i in range(start_index, end_index - 1, -1):
			update_card_position(items_pool[i], i + 1)
	update_card_position(moved_card, target_index)
	tween_update(render_event)
# 交换卡片
func swap_cards(pool_id_a: int, pool_id_b: int) -> void:
	var pool_size: int = items_pool.size()
	pool_id_a = clampi(pool_id_a, 0, pool_size - 1)
	pool_id_b = clampi(pool_id_b, 0, pool_size - 1)
	if pool_id_a == pool_id_b:
		return
	var card_a = items_pool[pool_id_a]
	var card_b = items_pool[pool_id_b]
	update_card_position(card_a, pool_id_b)
	update_card_position(card_b, pool_id_a)
	render_update()

func insert_non_render_item(node: Node, tree_index: int) -> bool:
	if node is RenderItem:
		push_error("Cannot insert RenderItem using this method. Use add_render_item_child instead.")
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
		print_debug("Inserted non-RenderItem at index %d. _divide_index moved from %d to %d" %
				   [tree_index, _divide_index - 1, _divide_index])
	else:
		var actual_index:int = tree_index
		if actual_index > get_child_count():
			actual_index = get_child_count()
		if node.get_parent():
			node.get_parent().remove_child(node)
		add_child(node)
		move_child(node, actual_index)
		print_debug("Inserted non-RenderItem at index %d. _divide_index remains %d" %
				   [actual_index, _divide_index])
	return true

## 移除非RenderItem节点
## node: 要移除的节点
## 如果节点在分界标记前，分界标记向前移动
func remove_non_render_item(node: Node) -> bool:
	if node is RenderItem:
		push_error("Cannot remove RenderItem using this method. Use remove_render_item_child instead.")
		return false
	if not is_instance_valid(node) or node.get_parent() != self:
		push_error("Node is not a child of this RenderArea.")
		return false
	var node_index:int = node.get_index()
	remove_child(node)
	if node_index < _divide_index:
		_divide_index -= 1
		print_debug("Removed non-RenderItem at index %d. _divide_index moved from %d to %d" %
				   [node_index, _divide_index + 1, _divide_index])
	return true
