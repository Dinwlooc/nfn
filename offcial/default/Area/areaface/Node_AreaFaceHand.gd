extends RealAreaFace


var original_position
var original_size
var area_target_position:Vector2
var area_target_size:Vector2
const time = 0.4
func ready_expand()->void:
	original_position = position
	original_size = size
	area_target_position = original_position
	area_target_size = original_size
	pass

func _process(_delta)-> void:
	if Engine.get_process_frames() % 2 == 0:
		card_move_expand()
	pass

func render_update():
	target_position = GlobalUIAnimation.generate_coordinates(area_target_position,area_target_size,area.real_card_pool.size())
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

func card_move_expand()->void:
	for i in range(0,area.real_card_pool.size()):
		area.real_card_pool[i].cardface.position.y += 0.3*sin((Time.get_ticks_msec()+i*200)*0.004)

func dragging_move(card):
	var _target_position = get_global_mouse_position()
	GlobalUIAnimation.tween_animations(card,{"position":_target_position},time)

func card_move()-> void:
	if area.real_card_pool.size() == 0||target_position.size()==0:
		return
	for i in range(0,area.real_card_pool.size()):
		var card_position = area.real_card_pool[i].position
		var _target_position = target_position[i]
		if area.real_card_pool[i].selected:
			_target_position.y += -40.0
		if !area.real_card_pool[i].dragged:
			GlobalUIAnimation.tween_animations(area.real_card_pool[i],{"position":_target_position},time)
	pass
