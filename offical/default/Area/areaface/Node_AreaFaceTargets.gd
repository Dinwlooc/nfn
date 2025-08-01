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
	pass

func render_update():
	target_position = GlobalUIAnimation.generate_coordinates(area_target_position,area_target_size,area.card_pool.size())
	tween_update()

func tween_update():
	card_move()

func _into_area():
	area_target_position = original_position - Vector2(0, 80)
	area_target_size = original_size + Vector2(0, 80)
	var list = {
		"position":area_target_position,
		"size":area_target_size,
		}
	GlobalUIAnimation.tween_animations(self,list,time)
	render_update()
	pass
	
func _outto_area():
	area_target_position = original_position
	area_target_size = original_size
	var list = {
		"position":area_target_position,
		"size":area_target_size,
		}
	GlobalUIAnimation.tween_animations(self,list,time)
	render_update()

func card_move()-> void:
	if area.card_pool.size() == 0||target_position.size()==0:
		return
	for i in range(0,area.card_pool.size()):
		var card:RenderCard = area.card_pool[i]
		var card_position = card.position
		var _target_position = target_position[i]
		if card.selected:
			_target_position.y += -40.0
		if !card.dragged:
			GlobalUIAnimation.tween_animations(card,{"position":_target_position},time)
	pass
