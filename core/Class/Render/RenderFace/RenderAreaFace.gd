extends Control
class_name RenderAreaFace

var hovering_card:RenderCard = null
var target_position:PackedVector2Array
@export var area:RenderArea
@export var area_name:StringName = &""
var in_area:bool = false
signal into_area
signal outto_area

func _ready()->void:
	if area:
		connect_to_area(area)
	into_area.connect(_into_area)
	outto_area.connect(_outto_area)
	ready_expand()

func connect_to_area(_area:RenderArea):
	_area.render_requested.connect(render_update)
	_area.tween_requested.connect(tween_update)
	_area.cards_added.connect(connect_cards_signals)

func render_update(render_event:RenderEvent = RenderEvent.new())-> void:
	tween_update(render_event)
	pass

func tween_update(render_event:RenderEvent = RenderEvent.new())->void:
	#只更新动画。
	pass

func _input(event)->void:
	if event is InputEventMouseMotion:
		try_dragging_move()
		var mouse_position = get_local_mouse_position()
		if Rect2(Vector2.ZERO,size).has_point(mouse_position):
			if !in_area:
				into_area.emit()
			in_area = true
		else:
			if in_area:
				outto_area.emit()
			in_area = false
		pass

func try_dragging_move()->bool:
	var control:RenderControl = area.control
	if control && control.get_dragged_area() == area:
		hover_detect_when_dragging(control.get_dragged_card())
		dragging_move(control.get_dragged_card())
		return true
	return false

func connect_cards_signals(cards:Array[RenderCard]):
	for card in cards:
		card.mouse_entered.connect(_on_card_mouse_entered.bind(card))
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
		
func hover_detect_when_dragging(dragged_card:RenderCard)->void:
	var mouse_position = get_global_mouse_position()
	if !hovering_card && dragged_card.is_hovering(mouse_position):
		for i in range(dragged_card.pool_id ,-1,-1):
			if !area.card_pool[i].dragged && area.card_pool[i].is_hovering(mouse_position):
				hovering_card = area.card_pool[i]
				hovering_card.hovering = true
				break
		return

func card_move()-> void:
	pass

func ready_expand()->void:
	pass

func dragging_move(card:RenderCard)->void:
	pass

func _into_area()->void:
	pass
	
func _outto_area()->void:
	pass
