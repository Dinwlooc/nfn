extends Control
class_name RenderAreaFace

var hovering_card:RenderCard = null
var target_position:PackedVector2Array
var area:RenderArea
var in_area:bool = false
signal into_area
signal outto_area

func _ready()->void:
	if get_parent_control()&&get_parent_control() is RenderArea:
		area = get_parent_control()
		area.render_requested.connect(render_update)
		area.tween_requested.connect(tween_update)
		area.card_added.connect(connect_card_signals)
		area.card_removed.connect(disconnect_card_signals)
	into_area.connect(_into_area)
	outto_area.connect(_outto_area)
	ready_expand()

func ready_expand()->void:
	pass

func render_update(render_event:RenderEvent = RenderEvent.new())-> void:
	#更新动画和渲染控制参数。
	tween_update(render_event)
	pass

func tween_update(render_event:RenderEvent = RenderEvent.new())->void:
	#只更新动画。
	pass

func _input(event)->void:
	if event is InputEventMouseMotion:
		var mouse_position = get_local_mouse_position()
		if GlobalConsole.card_on_drag&&GlobalConsole.card_on_drag.area == area:
			dragging_move(GlobalConsole.card_on_drag.card)
		if Rect2(Vector2.ZERO,size).has_point(mouse_position):
			#hover_card()
			if !in_area:
				into_area.emit()
			in_area = true
		else:
			if in_area:
				outto_area.emit()
			in_area = false
		pass

func connect_card_signals(card: RenderCard):
	if card.has_signal(&"mouse_entered"):
		card.mouse_entered.connect(_on_card_mouse_entered.bind(card))
	if card.has_signal(&"mouse_exited"):
		card.mouse_exited.connect(_on_card_mouse_exited.bind(card))

func disconnect_card_signals(card: RenderCard):
	if hovering_card == card:
		card.hovering = false
		hovering_card = null 
	if card.is_connected(&"mouse_entered", _on_card_mouse_entered):
		card.mouse_entered.disconnect(_on_card_mouse_entered)
	if card.is_connected(&"mouse_exited", _on_card_mouse_exited):
		card.mouse_exited.disconnect(_on_card_mouse_exited)

func _on_card_mouse_entered(card: RenderCard):
	if card.dragged:
		return
	if hovering_card and hovering_card != card:
		hovering_card.hovering = false
	hovering_card = card
	card.hovering = true

func _on_card_mouse_exited(card: RenderCard):
	if hovering_card == card:
		card.hovering = false
		hovering_card = null

func card_move()-> void:
	if area.card_pool.size() == 0||target_position.size()==0:
		return
	for i in range(0,area.card_pool.size()):
		var card_position = area.card_pool[i].position
		var _target_position = target_position[i]
		if !area.card_pool[i].dragged:
			UIAnimationUtils.tween_animations(area.card_pool[i],{^"position":_target_position})
	pass

func dragging_move(card:RenderCard)->void:
	pass

func _into_area()->void:
	pass
	
func _outto_area()->void:
	pass

func hover_detect_when_dragging(dragged_card:RenderCard)->void:
	var mouse_position = get_global_mouse_position()
	if !hovering_card && dragged_card.is_hovering(mouse_position):
		for i in range(dragged_card.pool_id ,-1,-1):
			if !area.card_pool[i].dragged && area.card_pool[i].is_hovering(mouse_position):
				hovering_card = area.card_pool[i]
				hovering_card.hovering = true
				break
		return
