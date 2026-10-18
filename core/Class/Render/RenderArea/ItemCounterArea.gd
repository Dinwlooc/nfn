## 计数型渲染区域：只维护 [member item_count] 与回收模式，不持有常驻卡牌子节点。
extends RenderArea
class_name ItemCounterArea

#==enums==
## 渲染项回收时机（AUTO：入区即回收；MANUAL：由调用方调 [method recycle_item]）
enum RecycleMode {
	AUTO,
	MANUAL
}

## 回收模式：入区即回收 / 由调用方手动回收
var recycle_mode: RecycleMode = RecycleMode.AUTO
## 当前计数
var item_count: int = 0

## 处理卡牌集合请求：把每张牌移入本区（AUTO 模式下随即回收）
## @override
func _process_item_set(item_set: RenderRequest.ItemSet) -> void:
	if not render_context:
		push_error("RenderContext not set in RenderArea")
		return
	for item_pack in item_set.items:
		var render_item: RenderItem = render_context.get_or_create_item(item_pack)
		if render_item.area_name == get_area_name():
			_update_item_data(render_item, item_pack)
			continue
		var current_area: RenderArea = render_context.get_render_area(render_item.area_name, render_item.player_id)
		if current_area:
			current_area.remove_item(render_item)
		add_item(render_item)

## 处理计数设置请求：从来源区扣减差额
## @override
func _process_item_count_set(item_count_set: RenderRequest.ItemCountSet) -> void:
	if item_count_set.total_count > item_count:
		var source_area:RenderArea =  render_context.get_render_area(item_count_set.source_area_name,item_count_set.source_area_player_id)
		if source_area:
			source_area.remove_item_count(item_count_set.total_count - item_count)
	item_count = item_count_set.total_count

## 加一张牌：登记区域并计数；AUTO 模式随即回收
## @override
func add_item(item: RenderItem, index: int = -1) -> void:
	item.area_name = get_area_name()
	_connect_item_to_area(item)
	item_count += 1
	if recycle_mode == RecycleMode.AUTO:
		_request_recycle_item(item)
	render_update(RenderEvent.new(RenderEvent.DefaultType.CARD_ADD))
	items_added.emit(item)

## 移除一张牌：计数减一并广播
## @override
func remove_item(item: RenderItem) -> void:
	remove_item_count(1)
	items_removed.emit(item)

## 按数量扣减计数（下限 0）
## @override
func remove_item_count(count: int) -> void:
	item_count = max(0, item_count - count)

## 按数量增加计数
## @override
func add_item_count(count: int) -> void:
	item_count += count

## 取当前计数
## @override
func get_item_count() -> int:
	return item_count

## 回收指定牌
func recycle_item(item: RenderItem) -> void:
	_request_recycle_item(item)

## 请求渲染上下文回收该牌
func _request_recycle_item(item: RenderItem) -> void:
	if render_context:
		render_context.request_recycle_item(item)
