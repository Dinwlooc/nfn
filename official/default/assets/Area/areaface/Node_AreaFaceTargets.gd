extends RenderAreaFace

var original_position:Vector2
var original_size:Vector2
var area_target_position:Vector2
var area_target_size:Vector2
@export var area_hand:RenderAreaHand
const TWEEN_TIME = 0.35

func ready_expand()->void:
	original_position = position
	original_size = size
	area_target_position = original_position
	area_target_size = original_size
	render_update()
	connect_to_areahand()
	GlobalRegistry.connect_renderarea(RenderArea.DefaultArea.HAND,func(_area):
		area_hand.selected.disconnect(quickly_select)
		area_hand = _area
		connect_to_areahand())

func connect_to_areahand()->void:
	area_hand.selected.connect(quickly_select)

func render_update(_render_event:RenderEvent = RenderEvent.new()):
	target_position = UIAnimationUtils.generate_coordinates(area_target_position,area_target_size,area.card_pool.size())
	tween_update()

func tween_update(_render_event:RenderEvent = RenderEvent.new()):
	card_move()

func _into_area()->void:
	area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.INTO_AREA))
	pass

func _outto_area()->void:
	area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.OUTTO_AREA))

func card_move()-> void:
	if area.card_pool.size() == 0||target_position.size()==0:
		return
	for i in range(0,area.card_pool.size()):
		var card:RenderCard = area.card_pool[i]
		var _target_position = target_position[i]
		UIAnimationUtils.tween_animations(card,{^"position":_target_position},TWEEN_TIME)
	pass

func quickly_select():
	if area.card_pool.size() > 0 && area.get_selected_cards().size() == 0:
		area.on_select(area.card_pool[0])
	pass
