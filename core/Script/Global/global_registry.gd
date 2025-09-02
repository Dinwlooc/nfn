extends Node

var maingame:Node
var	renderarea:Dictionary[StringName,RenderArea]
var console:Node
class DragState:
	var area:RenderArea
	var card:RenderCard
var timer:GameTimer
var system:System
var card_on_drag:DragState

func register_console(console_instance:Node)->void:
	console = console_instance
func register_maingame(maingame_instance:Node)->void:
	maingame = maingame_instance
func register_system(system_instance:System)->void:
	system = system_instance
func register_timer(timer_instance:GameTimer)->void:
	timer = timer_instance
func register_renderarea(renderarea_name:StringName,renderarea_instance:RenderArea)->void:
	renderarea[renderarea_name] = renderarea_instance
	
func set_card_on_drag(area:RenderArea,realcard:RenderCard)->void:
	remove_card_on_drag()
	card_on_drag = DragState.new()
	card_on_drag.area = area
	card_on_drag.card = realcard
	card_on_drag.card.dragged = true
	card_on_drag.area.tween_update()

func get_renderarea(renderarea_name:StringName)->RenderArea:
	if renderarea.has(renderarea_name):
		return renderarea[renderarea_name]
	return null

func remove_card_on_drag():
	if card_on_drag:
		card_on_drag.card.dragged = false
		card_on_drag.area.tween_update()
	card_on_drag = null
