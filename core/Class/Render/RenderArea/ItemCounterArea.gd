##只记录Item数量的区域
extends RenderArea
class_name ItemCounterArea

var item_count:int = 0

func add_item(item:RenderItem, index:int = -1) -> void:
	item_count += 1
	items_added.emit(item)

func remove_item(item:RenderItem) -> void:
	remove_items_by_uids(PackedInt32Array([item.get_id()]))

func get_item_count() -> int:
	return item_count
