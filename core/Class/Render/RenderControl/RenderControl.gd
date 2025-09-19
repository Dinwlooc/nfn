extends Control
class_name RenderControl

class DragState:
	var area:RenderArea
	var card:RenderCard
var card_on_drag:DragState
var render_manager: RenderManager = RenderManager.new()
signal dragged_update

func _ready() -> void:
	GlobalRegistry.register_singleton(GlobalRegistry.RENDER_CONTROL_TYPE,self)

func set_card_on_drag(area:RenderArea,realcard:RenderCard)->void:
	remove_card_on_drag()
	card_on_drag = DragState.new()
	card_on_drag.area = area
	card_on_drag.card = realcard
	card_on_drag.card.dragged = true
	card_on_drag.area.tween_update()
	dragged_update.emit()

func remove_card_on_drag():
	if card_on_drag:
		card_on_drag.card.dragged = false
		card_on_drag.area.tween_update()
	card_on_drag = null

func get_dragged_area()->RenderArea:
	if !card_on_drag:
		return null
	return card_on_drag.area

func get_dragged_card()->RenderCard:
	if !card_on_drag:
		return null
	return card_on_drag.card
