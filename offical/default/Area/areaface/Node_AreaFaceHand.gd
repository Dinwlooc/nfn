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

func _physics_process(delta: float) -> void:
	if Engine.get_process_frames() % 2 == 0:
		card_move_expand()
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

func card_move_expand()->void:
	for i in range(0,area.card_pool.size()):
		area.card_pool[i].position.y += 0.3*sin((Time.get_ticks_msec()+i*200)*0.004)

func dragging_move(card:RenderCard):
	var _target_position = get_global_mouse_position()
	card_move_rotate(card,_target_position)
	GlobalUIAnimation.tween_animations(card,{"position":_target_position},time).finished.connect(card_move_rotate.bind(card,_target_position))

func card_move_rotate(card:RenderCard, _target_position:Vector2):
	# 计算水平距离差
	var dx = card.position.x - _target_position.x
	var abs_dx = abs(dx)
	const max_distance = 300.0
	const max_rotation = -PI*0.167
	const rotate_time = 0.35
	var rotation_ratio = min(abs_dx / max_distance, 1.0)
	var rotation_sign = 1.0 if dx < 0 else -1.0
	var _target_rotation = rotation_sign * rotation_ratio * max_rotation
	GlobalUIAnimation.tween_animations(card, {"rotation": _target_rotation}, rotate_time)

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
			GlobalUIAnimation.tween_animations(card,{"position":_target_position},time).finished.connect(card_move_rotate.bind(card,_target_position))
	pass
