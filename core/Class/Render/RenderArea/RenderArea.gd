extends Control
class_name RenderArea

signal render_requested(render_event:RenderEvent)
signal tween_requested(render_event:RenderEvent)
signal selected()
signal item_add_requested(items:ItemPack, area:RenderArea)
signal items_added(item:RenderItem)
signal item_move_requested(item:RenderItem, new_index:int, area:RenderArea)
signal context_ready()

var area_name:StringName
var selected_items:Array[RenderItem] = []
var select_limit:int = 1
var render_context:RenderContext
var pack_type: StringName = &""

class DefaultArea:
	const HAND:StringName = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.HAND]
	const PLAYERS:StringName = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.PLAYERS]
	const STAGE:StringName = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.STAGE]

func _ready() -> void:
	ready_expand()

func ready_expand() -> void:
	pass

func process_request(request: RenderRequest) -> void:
	if request is RenderRequest.ItemSet:
		_process_item_set(request as RenderRequest.ItemSet)

# 新增：处理ItemSet请求
func _process_item_set(item_set: RenderRequest.ItemSet) -> void:
	if not render_context:
		push_error("RenderContext not set in RenderArea")
		return
	if pack_type == &"":
		push_error("RenderArea.pack_type not set")
		return
	if item_set.item_type != pack_type:
		push_error("ItemSet.item_type (%s) does not match area.pack_type (%s)" % [item_set.item_type, pack_type])
		return
	for item_pack in item_set.items:
		var render_item = render_context.get_render_item_by_id(item_pack.get_class_name(), item_pack.get_id())
		if not render_item:
			item_add_requested.emit(item_pack, self)
		else:
			var current_area:RenderArea = render_context.get_render_area(render_item.area_name)
			if current_area != self:
				current_area.m_data(render_item, item_pack)
			else:
				# 在同一个区域，只更新数据
				_update_item_data(render_item, item_pack)

# 新增：更新ItemPack数据
func _update_item_data(render_item: RenderItem, item_pack: ItemPack) -> void:
	# 暂时留空，指示要求"暂不实现"
	# 这里需要调用ItemPack的合并接口
	pass
func _exit_tree() -> void:
	if render_context:
		render_context.unregister_render_area(area_name)

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

func on_drag(item:RenderItem) -> void:
	if not render_context:
		return
	if Input.get_mouse_button_mask() == 1:
		render_context.set_card_on_drag(self, item)
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

# 抽象方法 - 子类必须实现
func add_item(item:RenderItem, index:int = -1) -> void:
	push_error("add_item must be implemented in subclass")

func remove_item(item:RenderItem) -> void:
	push_error("remove_item must be implemented in subclass")

func remove_items_by_uids(uids:PackedInt32Array) -> Array[RenderItem]:
	push_error("remove_items_by_uids must be implemented in subclass")
	return []

func move_item_to_index(current_pool_id:int, target_index:int, render_event:RenderEvent = RenderEvent.new()) -> void:
	push_error("move_item_to_index must be implemented in subclass")

func swap_items(pool_id_a:int, pool_id_b:int) -> void:
	push_error("swap_items must be implemented in subclass")

func get_item_count() -> int:
	push_error("get_item_count must be implemented in subclass")
	return 0

func get_item_by_uid(uid:int) -> RenderItem:
	push_error("get_item_by_uid must be implemented in subclass")
	return null

func get_item_by_index(index:int) -> RenderItem:
	push_error("get_item_by_index must be implemented in subclass")
	return null
