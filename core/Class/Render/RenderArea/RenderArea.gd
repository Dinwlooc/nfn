extends Control
class_name RenderArea
#总控区域渲染与交互。
var area_name:StringName
var items_pool:Array[RenderItem] = []
@export var item_id_to_instance: Dictionary[int,RenderItem] = {}
var selected_items: Array[RenderItem] = []
var select_limit:int = 1
var init_child_count:int
signal render_requested(render_event:RenderEvent)
signal tween_requested(render_event:RenderEvent)
signal selected()
signal items_add_requested(items:Array[TransPack])
signal items_added(item:RenderItem)
signal items_remove_requested(uids:PackedInt32Array)
signal item_move_requested(item: RenderItem, new_index: int)
signal context_ready()
class DefaultArea:
	const HAND:StringName = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.HAND]
	const PLAYERS:StringName = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.PLAYERS]
	const STAGE:StringName = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.STAGE]
var render_context: RenderContext

func _ready():
	init_child_count = get_child_count()
	ready_expand()
	pass

func ready_expand()->void:
	pass

func _exit_tree():
	if render_context:
		render_context.unregister_render_area(area_name)

func render_update(render_event:RenderEvent = RenderEvent.new())-> void:
	render_requested.emit(render_event)
	pass

func tween_update(render_event:RenderEvent = RenderEvent.new())->void:
	tween_requested.emit(render_event)
	pass

func process_request(request:RenderRequest)->void:
	pass

func set_render_context(context: RenderContext) -> void:
	render_context = context
	if render_context.dragged_update.is_connected(tween_update.unbind(1)):
		render_context.dragged_update.disconnect(tween_update)
	render_context.dragged_update.connect(tween_update.unbind(1))

# 数据池操作：仅管理空间参数
func set_item_to_pool(item: RenderItem, index: int) -> void:
	item.area_name = area_name
	item.render_context = render_context
	item.pool_id = index
	item_id_to_instance[item.get_id()] = item
	if index >= items_pool.size():
		items_pool.append(item)
	else:
		items_pool[index] = item
	items_added.emit(item)

func remove_items_by_uids(uids: PackedInt32Array) -> Array[RenderItem]:
	var removed_items: Array[RenderItem] = []
	var min_index := -1
	for uid in uids:
		if item_id_to_instance.has(uid):
			var item = item_id_to_instance[uid]
			removed_items.append(item)
			var pool_id = item.pool_id
			if min_index == -1 || pool_id < min_index:
				min_index = pool_id
			if item in selected_items:
				selected_items.erase(item)
			item_id_to_instance.erase(uid)
			items_pool[pool_id] = null
	if min_index != -1:
		compact_pool(min_index, uids.size())
	return removed_items

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

func on_select(card: RenderItem) -> void:
	if card.selected:
		card.selected = false
		selected_items.erase(card)  # 精确移除实例
	else:
		if selected_items.size() >= select_limit:
			selected_items[0].selected = false
			selected_items.remove_at(0)
		card.selected = true
		selected_items.append(card)
	tween_update()
	selected.emit()

func on_drag(pool_id:int)->void:
	if !render_context :
		return
	if Input.get_mouse_button_mask()==1:
		render_context.set_card_on_drag(self,items_pool[pool_id])
	else:
		render_context.remove_card_on_drag()
	pass

func get_selected_cards()->Array[RenderItem]:
	return selected_items

func get_selected_ids() -> PackedInt32Array:
	var ids = PackedInt32Array()
	ids.resize(selected_items.size())
	for i in range(selected_items.size()):
		ids[i] = selected_items[i].get_id()
	return ids

func update_card_position(item: RenderItem, new_index: int) -> void:
	item.pool_id = new_index
	if new_index >= items_pool.size():
		items_pool.append(item)
	else:
		items_pool[new_index] = item
	item_move_requested.emit(item, new_index)
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
			# 现在通过update_card_position统一更新位置和items_pool
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
