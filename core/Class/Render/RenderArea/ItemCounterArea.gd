##只记录Item数量的区域
extends RenderArea
class_name ItemCounterArea

var item_count:int = 0

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
		var render_item:RenderItem = render_context.get_render_item_by_id(item_pack.get_class_name(), item_pack.get_id())
		if not render_item:
			return
		var current_area:RenderArea = render_context.get_render_area(render_item.area_name)
		if current_area != self:
			current_area.remove_item(render_item)
		add_item(render_item)

func add_item(item:RenderItem, index:int = -1) -> void:
	item_count += 1
	items_added.emit(item)

func remove_item_count(remove_count:int) -> void:
	item_count = max(0, item_count - remove_count)

func add_item_count(add_count:int) -> void:
	item_count += add_count

func get_item_count() -> int:
	return item_count
