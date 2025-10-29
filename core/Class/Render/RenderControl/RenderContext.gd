extends RefCounted
class_name RenderContext

class DragState:
	var area:RenderArea
	var card:RenderCard

var card_on_drag: DragState
signal dragged_update

func set_card_on_drag(area: RenderArea, realcard: RenderCard) -> void:
	remove_card_on_drag()
	card_on_drag = DragState.new()
	card_on_drag.area = area
	card_on_drag.card = realcard
	card_on_drag.card.dragged = true
	card_on_drag.area.tween_update()
	dragged_update.emit()

func remove_card_on_drag() -> void:
	if card_on_drag:
		card_on_drag.card.dragged = false
		card_on_drag.area.tween_update()
	card_on_drag = null

func get_dragged_area() -> RenderArea:
	return card_on_drag.area if card_on_drag else null

func get_dragged_card() -> RenderCard:
	return card_on_drag.card if card_on_drag else null
