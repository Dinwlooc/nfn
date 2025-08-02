extends RenderAreaFace

var original_position
var original_size
var area_target_position:Vector2
var area_target_size:Vector2
const time = 0.35

func ready_expand()->void:
	original_position = position
	original_size = size
	area_target_position = original_position
	area_target_size = original_size
	render_update()
	pass

func render_update():
	target_position = GlobalUIAnimation.generate_coordinates(area_target_position,area_target_size,area.card_pool.size())
	tween_update()

func tween_update():
	card_move()

func _into_area():
	render_update()
	pass
	
func _outto_area():
	render_update()

func card_move()-> void:
	if area.card_pool.size() == 0||target_position.size()==0:
		return
	for i in range(0,area.card_pool.size()):
		var card:RenderCard = area.card_pool[i]
		var card_position = card.position
		var _target_position = target_position[i]
		GlobalUIAnimation.tween_animations(card,{"position":_target_position},time)
	pass
