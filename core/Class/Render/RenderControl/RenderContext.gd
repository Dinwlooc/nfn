extends RefCounted
class_name RenderContext

const PUBLIC_PLAYER_ID: int = 1

var area_manager: RenderAreaManager
var item_manager: RenderItemManager
var state_manager: RenderStateManager
## 操作管理器（保持不变）
var operation_manager: OperationManager

func _init() -> void:
	area_manager = RenderAreaManager.new()
	item_manager = RenderItemManager.new()
	state_manager = RenderStateManager.new()

## 以下为委托方法，保留原函数名以最小化外部改动
func connect_renderarea(area_name: StringName, callback: Callable, player_id: int = PUBLIC_PLAYER_ID) -> void:
	area_manager.connect_renderarea(area_name, callback, player_id)

func disconnect_renderarea(area_name: StringName, callback: Callable, player_id: int = PUBLIC_PLAYER_ID) -> void:
	area_manager.disconnect_renderarea(area_name, callback, player_id)

func register_render_area(area: RenderArea, player_id: int = PUBLIC_PLAYER_ID) -> void:
	area_manager.register_render_area(area, player_id)

func unregister_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> void:
	area_manager.unregister_render_area(area_name, player_id)

func get_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> RenderArea:
	return area_manager.get_render_area(area_name, player_id)

func get_all_player_ids() -> Array[int]:
	return area_manager.get_all_player_ids()

func get_player_areas(player_id: int = PUBLIC_PLAYER_ID) -> Dictionary[StringName, RenderArea]:
	return area_manager.get_player_areas(player_id)

func create_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> RenderArea:
	return area_manager.create_render_area(area_name, player_id)

## 区域销毁包含额外的 item 清理和拖拽检查，保留在 RenderContext
func delete_render_area(area: RenderArea) -> void:
	# 检查拖拽状态
	if state_manager.card_on_drag:
		if state_manager.card_on_drag.area == area:
			state_manager.remove_card_on_drag()
		else:
			var dragged_card = state_manager.card_on_drag.card
			if dragged_card and dragged_card.get_parent() == area:
				state_manager.remove_card_on_drag()
	# 回收所有子 RenderItem
	for child in area.get_children():
		if child is not RenderItem:
			continue
		var item: RenderItem = child
		area.remove_child(item)
		if item.data:
			item_manager.unregister_render_item(item.data.get_class_name(), item.data.get_id())
		area._disconnect_item_from_area(item)
		item_manager.recycle_item_immediate(item)
	area.queue_free()

func remove_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> void:
	var area = get_render_area(area_name, player_id)
	if not area:
		push_warning("Attempted to remove non-existent render area: ", area_name, " for player ", player_id)
		return
	unregister_render_area(area_name, player_id)
	delete_render_area(area)

## RenderItem 管理委托
func get_or_create_item(item_pack: ItemPack) -> RenderItem:
	return item_manager.get_or_create_item(item_pack, self)

func get_item(item_pack: ItemPack) -> RenderItem:
	return item_manager.get_item(item_pack)

## 延迟回收物品（接口完全保持原样）
func request_recycle_item(item: RenderItem) -> void:
	call_deferred(&"_recycle_item_deferred", item)

func _recycle_item_deferred(item: RenderItem) -> void:
	if item.data:
		var item_type = item.data.get_class_name()
		var item_id = item.data.get_id()
		item_manager.unregister_render_item(item_type, item_id)
	if item.area_name:
		for player_id in area_manager.render_areas:
			var areas = area_manager.render_areas[player_id]
			if areas.has(item.area_name):
				var current_area = areas[item.area_name]
				if current_area:
					current_area._disconnect_item_from_area(item)
				break
	item_manager.recycle_item_to_pool(item)

func register_render_item(item_type: StringName, item_id: int, render_item: RenderItem) -> void:
	item_manager.register_render_item(item_type, item_id, render_item)

func unregister_render_item(item_type: StringName, item_id: int) -> void:
	item_manager.unregister_render_item(item_type, item_id)

func get_render_item_by_id(item_type: StringName, item_id: int) -> RenderItem:
	return item_manager.get_render_item_by_id(item_type, item_id)

## 拖拽与状态管理委托
func set_card_on_drag(area: RenderArea, realcard: RenderItem) -> void:
	state_manager.set_card_on_drag(area, realcard)

func remove_card_on_drag() -> void:
	state_manager.remove_card_on_drag()

func get_dragged_area() -> RenderArea:
	return state_manager.get_dragged_area()

func get_dragged_card() -> RenderItem:
	return state_manager.get_dragged_card()

func notify_stage(stage_name: StringName, current_player_id: int, params: Dictionary = {}) -> void:
	state_manager.notify_stage(stage_name, current_player_id, params)

func get_current_stage_name() -> StringName:
	return state_manager.get_current_stage_name()

func get_current_stage_player_id() -> int:
	return state_manager.get_current_stage_player_id()

## 其他
func set_operation_manager(manager: OperationManager) -> void:
	operation_manager = manager

func get_operation_manager() -> OperationManager:
	return operation_manager
