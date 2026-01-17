##只记录Item数量的区域
extends RenderArea
class_name ItemCounterArea

var item_count:int = 0

func add_item(item:RenderItem, index:int = -1) -> void:
	item_count += 1
	items_added.emit(item)

func remove_item_count(remove_count:int) -> void:
	item_count = max(0, item_count - remove_count)

func add_item_count(add_count:int) -> void:
	item_count += add_count

func get_item_count() -> int:
	return item_count
