extends RenderArea
class_name ItemCounterArea

enum RecycleMode {
	AUTO,
	MANUAL
}

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

func _process_item_count_set(item_count_set: RenderRequest.ItemCountSet) -> void:
	if item_count_set.total_count > item_count:
		var source_area:RenderArea =  render_context.get_render_area(item_count_set.source_area_name,item_count_set.source_area_player_id)
		if source_area:
			source_area.remove_item_count(item_count_set.total_count - item_count)
	item_count = item_count_set.total_count

func add_item(item: RenderItem, index: int = -1) -> void:
	item_count += 1
	if recycle_mode == RecycleMode.AUTO:
		_request_recycle_item(item)
	items_added.emit(item)

func remove_item(item: RenderItem) -> void:
	remove_item_count(1)

func remove_item_count(count: int) -> void:
	item_count = max(0, item_count - count)
	items_removed.emit(null)

func add_item_count(count: int) -> void:
	item_count += count

func get_item_count() -> int:
	return item_count

func recycle_item(item: RenderItem) -> void:
	_request_recycle_item(item)

func _request_recycle_item(item: RenderItem) -> void:
	if render_context:
		render_context.request_recycle_item(item)
