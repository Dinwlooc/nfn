extends Control
class_name RealAreaFace

var hovering_id:int = -1
var target_position:Array
var area:RealArea
var in_area:bool = false
signal into_area
signal outto_area

func _ready():
	if get_parent_control()&&get_parent_control() is RealArea:
		area = get_parent_control()
		area.areaface = self
	into_area.connect(_into_area)
	outto_area.connect(_outto_area)
	ready_expand()

func ready_expand()->void:
	pass

func render_update()-> void:
	#更新动画和渲染控制参数。
	tween_update()
	pass

func tween_update()->void:
	#只更新动画。
	pass

func _input(event):
	if event is InputEventMouseMotion:
		var mouse_position = get_local_mouse_position()
		if GlobalConsole.card_on_drag&&GlobalConsole.card_on_drag["area"] == area:
			dragging_move(GlobalConsole.card_on_drag["card"])
		if Rect2(Vector2.ZERO,size).has_point(mouse_position):
			hover_card()
			if !in_area:
				emit_signal("into_area")
			in_area = true
		else:
			if in_area:
				emit_signal("outto_area")
			in_area = false
		pass

func hover_card()->void:
	var mouse_position = get_global_mouse_position()
	if hovering_id >= area.real_card_pool.size():
		hovering_id = -1
	if hovering_id!=-1&&!area.real_card_pool[hovering_id].is_hovering(mouse_position):
		area.real_card_pool[hovering_id].hovering = false
		hovering_id = -1
	if hovering_id == -1:
		for i in range(0,area.real_card_pool.size()):
			if area.real_card_pool[-1-i].is_hovering(mouse_position):
				hovering_id = area.real_card_pool.size()-i-1
				break
		if hovering_id != -1:
			area.real_card_pool[hovering_id].hovering = true
		return
	elif hovering_id >= area.real_card_pool.size()-1||!area.real_card_pool[hovering_id+1].is_hovering(mouse_position):
		#检查重叠情况
		return
	else:
		area.real_card_pool[hovering_id].hovering = false
		#对重叠进行正序扫描
		for i in range(hovering_id+1,area.real_card_pool.size()):
			hovering_id = i
			if !area.real_card_pool[i].is_hovering(mouse_position):
				hovering_id += -1
				break
		area.real_card_pool[hovering_id].hovering = true

	
	
func card_move()-> void:
	if area.real_card_pool.size() == 0||target_position.size()==0:
		return
	for i in range(0,area.real_card_pool.size()):
		var card_position = area.real_card_pool[i].position
		var _target_position = target_position[i]
		if !area.real_card_pool[i].dragged:
			GlobalUIAnimation.tween_animations(area.real_card_pool[i],{"position":_target_position})
	pass

func dragging_move(card)->void:
	pass

func _into_area():
	pass
	
func _outto_area():
	pass
