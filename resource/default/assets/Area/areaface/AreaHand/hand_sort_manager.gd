## 手牌排序管理器：管理有序性计数器、排序执行与缓存。
extends RefCounted

## 有序性计数器：手动交换、卡牌增加时 +1；排序完成后归零。初始为0（有序）。
var order_dirty_counter: int = 0
## 是否有缓存的排序请求（动画/排序进行中产生的请求最多缓存一次）。
var pending_sort_request: bool = false
## 是否正在排序中。
var is_sorting: bool = false

## 请求一次排序（自动或手动）。若正在排序中则缓存，否则立即开始。
## @param area 目标 RenderArea
## @param on_sort_start 排序开始时调用的回调（用于禁用按钮）
## @param on_sort_end 排序结束时调用的回调（用于启用按钮）
func request_sort(area: RenderArea, on_sort_start: Callable, on_sort_end: Callable) -> void:
	if is_sorting:
		if not pending_sort_request:
			pending_sort_request = true
		return
	_start_sort(area, on_sort_start, on_sort_end)

## 开始排序流程（设置状态、执行、完成后处理缓存）。
func _start_sort(area: RenderArea, on_sort_start: Callable, on_sort_end: Callable) -> void:
	is_sorting = true
	if on_sort_start.is_valid():
		on_sort_start.call()
	await _quick_sort_cards(area)
	is_sorting = false
	if on_sort_end.is_valid():
		on_sort_end.call()
	if pending_sort_request:
		pending_sort_request = false
		_start_sort(area, on_sort_start, on_sort_end)

## 单次排序：按类型分组，组内按 ID 排序，然后一次性重排。
func _quick_sort_cards(area: RenderArea) -> void:
	var pool: Array[RenderItem] = area.items_pool
	if pool.is_empty():
		return
	# 按类型分组
	var type_map: Dictionary = {}
	for item in pool:
		var type: StringName = item.data.get_card_type()
		if not type_map.has(type):
			type_map[type] = PackedInt32Array()
		type_map[type].append(item.data.id)
	# 定义类型顺序（攻击、防御、法术）
	var type_order: Array[StringName] = [
		GlobalConstants.DefaultCard.ATTACK,
		GlobalConstants.DefaultCard.DEFENCE,
		GlobalConstants.DefaultCard.SPELL
	]
	var sorted_ids: PackedInt32Array = PackedInt32Array()
	for t in type_order:
		if type_map.has(t):
			var ids: PackedInt32Array = type_map[t]
			ids.sort()
			sorted_ids += ids
	for t in type_map.keys():
		if t not in type_order:
			var ids: PackedInt32Array = type_map[t]
			ids.sort()
			sorted_ids += ids
	area.rearrange_items(sorted_ids, pool[0].data.get_class_name())
	area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.SWAP_CARD))
	order_dirty_counter = 0

## 重置计数器（通常由外部手动排序后调用，但排序内部已重置）。
func reset_counter() -> void:
	order_dirty_counter = 0

## 增加计数器（卡牌添加或手动交换时调用）。
func increment_counter() -> void:
	order_dirty_counter += 1

## 判断是否应该自动触发排序（计数器从0变为1时）。
func should_auto_sort() -> bool:
	return order_dirty_counter == 1

## 手动排序按钮是否可用（计数器>0时可点击）。
func can_manual_sort() -> bool:
	return order_dirty_counter > 0
