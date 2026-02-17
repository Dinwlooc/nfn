##只记录Item数量的区域
extends RenderArea
class_name ItemCounterArea

var item_count:int = 0

func _process_item_set(item_set: RenderRequest.ItemSet) -> void:
	if not render_context:
		push_error("RenderContext not set in RenderArea")
		return
	for item_pack in item_set.items:
		var render_item: RenderItem = render_context.get_or_create_item(item_pack)
		if render_item.area_name == get_area_name():
			_update_item_data(render_item, item_pack)
		else:
			var current_area = render_context.get_render_area(render_item.area_name)
			if current_area:
				current_area.remove_item(render_item)
			add_item(render_item)

func add_item(item:RenderItem, index:int = -1) -> void:
	item_count += 1
	if render_context:
		render_context.request_recycle_item(item)

func remove_item_count(remove_count:int) -> void:
	item_count = max(0, item_count - remove_count)

func add_item_count(add_count:int) -> void:
	item_count += add_count

func get_item_count() -> int:
	return item_count
