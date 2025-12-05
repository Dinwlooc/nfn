extends AreaFace

var original_position:Vector2
var original_size:Vector2
var area_target_position:Vector2
var area_target_size:Vector2
const TWEEN_TIME = 0.35

func _ready()->void:
	super._ready()
	original_position = position
	original_size = size
	area_target_position = original_position
	area_target_size = original_size

func _on_context_ready()->void:
	render_update()
	area.render_context.connect_renderarea(RenderArea.DefaultArea.HAND,_on_render_area_registered)

func _on_render_area_registered(area:RenderArea)->void:
	area.selected.connect(quickly_select)

func render_update(_render_event:RenderEvent = RenderEvent.new()):
	target_position = UIAnimationUtils.generate_coordinates(area_target_position,area_target_size,area.items_pool.size())
	tween_update()

func tween_update(_render_event:RenderEvent = RenderEvent.new()):
	card_move()

func _into_area()->void:
	area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.INTO_AREA))
	pass

func _outto_area()->void:
	area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.OUTTO_AREA))

func card_move()-> void:
	if area.items_pool.size() == 0||target_position.size()==0:
		return
	for i in range(0,area.items_pool.size()):
		var card:RenderItem = area.items_pool[i]
		var _target_position = target_position[i]
		UIAnimationUtils.tween_animations(card,{^"position":_target_position},TWEEN_TIME)
	pass

func quickly_select():
	if area.items_pool.size() > 0 && area.get_selected_cards().size() == 0:
		area.on_select(area.items_pool[0])
	pass
