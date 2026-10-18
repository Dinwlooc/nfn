## 渲染上下文：聚合区域/卡牌/状态/操作四个管理器，作为 Face 层与 [RenderControl] 的统一入口。
## 自身不持有渲染状态，只做转发与跨管理器协调（删除区域时联动清拖拽态、回收卡牌）。
extends RefCounted
class_name RenderContext

## 公共视角的玩家 id
const PUBLIC_PLAYER_ID: int = 1

## 区域管理器
var area_manager: RenderAreaManager
## 渲染项管理器
var item_manager: RenderItemManager
## 状态管理器
var state_manager: RenderStateManager
## 操作请求管理器
var operation_manager: OperationManager

## 构造：创建三个默认管理器
func _init() -> void:
	area_manager = RenderAreaManager.new()
	item_manager = RenderItemManager.new()
	state_manager = RenderStateManager.new()

# ================= 阶段通知接口 =================
## 通知主阶段变更
## @delegates
func notify_main_stage(stage_name: StringName, player_id: int, params: Dictionary = {}) -> void:
	state_manager.notify_main_stage(stage_name, player_id, params)

## 通知临时阶段变更
## @delegates
func notify_temp_stage(stage_name: StringName, turn_player_id: int, stage_owner_id: int, params: Dictionary = {}) -> void:
	state_manager.notify_temp_stage(stage_name, turn_player_id, stage_owner_id, params)

## 通知阶段变更（由状态管理器决定主阶段或临时阶段）
## @delegates
func notify_stage(stage_name: StringName, current_player_id: int, params: Dictionary = {}) -> void:
	state_manager.notify_stage(stage_name, current_player_id, params)

## 取当前阶段名（优先临时阶段，回退主阶段）
func get_current_stage_name() -> StringName:
	if not state_manager.get_current_stage_name().is_empty():
		return state_manager.get_current_stage_name()
	return state_manager.main_stage_name

## 取当前阶段行动玩家 id（临时阶段取归属者，否则取主阶段玩家）
func get_current_stage_player_id() -> int:
	if not state_manager.temp_stage_name.is_empty():
		return state_manager.temp_stage_owner_id
	return state_manager.main_stage_player_id

# ================= 区域管理委托 =================
## 注册区域回调（回调签名：func(new_area: RenderArea, old_area: RenderArea)）
## @delegates
func connect_renderarea(area_name: StringName, callback: Callable, player_id: int = PUBLIC_PLAYER_ID) -> void:
	area_manager.connect_renderarea(area_name, callback, player_id)

## 移除区域回调
## @delegates
func disconnect_renderarea(area_name: StringName, callback: Callable, player_id: int = PUBLIC_PLAYER_ID) -> void:
	area_manager.disconnect_renderarea(area_name, callback, player_id)

## 注册区域实例（支持替换）
## @delegates
func register_render_area(area: RenderArea, player_id: int = PUBLIC_PLAYER_ID) -> void:
	area_manager.register_render_area(area, player_id)

## 注销区域
## @delegates
func unregister_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> void:
	area_manager.unregister_render_area(area_name, player_id)

## 取区域实例
func get_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> RenderArea:
	return area_manager.get_render_area(area_name, player_id)

## 取所有已注册玩家 id
func get_all_player_ids() -> Array[int]:
	return area_manager.get_all_player_ids()

## 取指定玩家的全部区域（字典副本）
func get_player_areas(player_id: int = PUBLIC_PLAYER_ID) -> Dictionary[StringName, RenderArea]:
	return area_manager.get_player_areas(player_id)

## 创建并注册区域
## @delegates
func create_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> RenderArea:
	return area_manager.create_render_area(area_name, player_id)

## 删除区域：注销并联动清理拖拽态与卡牌
## @delegates
func delete_render_area(area: RenderArea) -> void:
	if state_manager.card_on_drag:
		if state_manager.card_on_drag.area == area:
			state_manager.remove_card_on_drag()
		else:
			var dragged_card: RenderItem = state_manager.card_on_drag.card
			if dragged_card and dragged_card.get_parent() == area:
				state_manager.remove_card_on_drag()
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

## 按名称注销区域
## @delegates
func remove_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> void:
	var area: RenderArea = get_render_area(area_name, player_id)
	if not area:
		push_warning("Attempted to remove non-existent render area: ", area_name, " for player ", player_id)
		return
	unregister_render_area(area_name, player_id)
	delete_render_area(area)

# ================= RenderItem 管理委托 =================
## 取或创建渲染项
## @delegates
func get_or_create_item(item_pack: ItemPack) -> RenderItem:
	return item_manager.get_or_create_item(item_pack, self)

## 取已存在的渲染项
func get_item(item_pack: ItemPack) -> RenderItem:
	return item_manager.get_item(item_pack)

## 请求回收渲染项（延迟到帧末执行）
## @delegates
func request_recycle_item(item: RenderItem) -> void:
	call_deferred(&"_recycle_item_deferred", item)

## 延迟回收：注销登记并释放渲染项
## @delegates
func _recycle_item_deferred(item: RenderItem) -> void:
	if item.data:
		var item_type: StringName = item.data.get_class_name()
		var item_id: int = item.data.get_id()
		item_manager.unregister_render_item(item_type, item_id)
	if item.area_name:
		for player_id: int in area_manager.render_areas:
			var areas: Dictionary = area_manager.render_areas[player_id]
			if areas.has(item.area_name):
				var current_area: RenderArea = areas[item.area_name]
				if current_area:
					current_area._disconnect_item_from_area(item)
				break
	item_manager.recycle_item_to_pool(item)

## 按类型与 id 登记渲染项
## @delegates
func register_render_item(item_type: StringName, item_id: int, render_item: RenderItem) -> void:
	item_manager.register_render_item(item_type, item_id, render_item)

## 注销渲染项登记
## @delegates
func unregister_render_item(item_type: StringName, item_id: int) -> void:
	item_manager.unregister_render_item(item_type, item_id)

## 按类型与 id 取渲染项
func get_render_item_by_id(item_type: StringName, item_id: int) -> RenderItem:
	return item_manager.get_render_item_by_id(item_type, item_id)

# ================= 拖拽与状态管理委托 =================
## 记录拖拽态
## @delegates
func set_card_on_drag(area: RenderArea, realcard: RenderItem) -> void:
	state_manager.set_card_on_drag(area, realcard)

## 清除拖拽态
## @delegates
func remove_card_on_drag() -> void:
	state_manager.remove_card_on_drag()

## 取拖拽起点区域
func get_dragged_area() -> RenderArea:
	return state_manager.get_dragged_area()

## 取被拖拽卡牌
func get_dragged_card() -> RenderItem:
	return state_manager.get_dragged_card()

# ================= 操作管理 =================
## 注入操作请求管理器
## @side_effect
func set_operation_manager(manager: OperationManager) -> void:
	operation_manager = manager

## 取操作请求管理器
func get_operation_manager() -> OperationManager:
	return operation_manager
