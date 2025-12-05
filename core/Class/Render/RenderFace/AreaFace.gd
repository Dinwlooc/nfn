extends Control
class_name AreaFace

var hovering_card:RenderItem = null
var target_position:PackedVector2Array
@export var area:RenderArea
@export var face_name:StringName = &""
var in_area:bool = false
signal into_area
signal outto_area

func _ready()->void:
	if area:
		connect_to_area(area)
	into_area.connect(_into_area)
	outto_area.connect(_outto_area)

func connect_to_area(_area:RenderArea):
	_area.render_requested.connect(render_update)
	_area.tween_requested.connect(tween_update)
	_area.items_added.connect(connect_cards_signals)
	_area.context_ready.connect(_on_context_ready)

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

func try_dragging_move()->bool:
	var context:RenderContext = area.render_context
	var card:RenderItem = context.get_dragged_card()
	if context && card && card.area_name == area.area_name:
		dragging_move(card)
		return true
	return false

func connect_cards_signals(card:RenderItem):
	card.mouse_entered.connect(_on_card_mouse_entered.bind(card))
	card.mouse_exited.connect(_on_card_mouse_exited.bind(card))

func disconnect_card_signals(card: RenderItem):
	if hovering_card == card:
		card.hovering = false
		hovering_card = null
	if card.is_connected(&"mouse_entered", _on_card_mouse_entered):
		card.mouse_entered.disconnect(_on_card_mouse_entered)
	if card.is_connected(&"mouse_exited", _on_card_mouse_exited):
		card.mouse_exited.disconnect(_on_card_mouse_exited)

func _on_card_mouse_entered(card: RenderItem):
	if card.dragged:
		return
	if hovering_card and hovering_card != card:
		hovering_card.hovering = false
	hovering_card = card
	card.hovering = true

func _on_card_mouse_exited(card: RenderItem):
	if hovering_card == card:
		card.hovering = false
		hovering_card = null

func card_move()-> void:
	pass

func dragging_move(_card:RenderItem)->void:
	pass

func _into_area()->void:
	pass

func _outto_area()->void:
	pass

func _on_context_ready()->void:
	pass
