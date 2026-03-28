## 只记录 Item 数量的区域
extends RenderArea
class_name ItemCounterArea

## 回收模式枚举
enum RecycleMode {
	AUTO,   ## 自动模式：add_item 时自动请求回收
	MANUAL  ## 手动模式：需要外部主动调用回收通知
}

## 当前回收模式，默认为自动
var recycle_mode: RecycleMode = RecycleMode.AUTO
var item_count: int = 0

func _process_item_set(item_set: RenderRequest.ItemSet) -> void:
	if not render_context:
		push_error("RenderContext not set in RenderArea")
		return
	for item_pack in item_set.items:
		var render_item: RenderItem = render_context.get_or_create_item(item_pack)
		if render_item.area_name == get_area_name():
			_update_item_data(render_item, item_pack)
		else:
			var current_area: RenderArea = render_context.get_render_area(render_item.area_name, render_item.player_id)
			if current_area:
				current_area.remove_item(render_item)
			add_item(render_item)

func add_item(item: RenderItem, index: int = -1) -> void:
	item_count += 1
	# 自动模式下自动请求回收
	if recycle_mode == RecycleMode.AUTO:
		_request_recycle_item(item)
	items_added.emit(item)

func remove_item_count(remove_count: int) -> void:
	item_count = max(0, item_count - remove_count)
	items_removed.emit(null)

func add_item_count(add_count: int) -> void:
	item_count += add_count

func get_item_count() -> int:
	return item_count

## 手动请求回收一个 RenderItem（仅在手动模式下由外部调用）
func recycle_item(item: RenderItem) -> void:
	_request_recycle_item(item)

## 内部回收通知方法，提取自原 add_item 逻辑
func _request_recycle_item(item: RenderItem) -> void:
	if render_context:
		render_context.request_recycle_item(item)
