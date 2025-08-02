extends Control
class_name RenderAreaFace

var hovering_id:int = -1
var target_position:Array
var area:RenderArea
var in_area:bool = false
signal into_area
signal outto_area

func _ready()->void:
	if get_parent_control()&&get_parent_control() is RenderArea:
		area = get_parent_control()
		area.render_requested.connect(render_update)
		area.tween_requested.connect(tween_update)
	into_area.connect(_into_area)
	outto_area.connect(_outto_area)
	ready_expand()

func ready_expand()->void:
	pass

func render_update(expend_render_property:Dictionary = {})-> void:
	#更新动画和渲染控制参数。
	tween_update(expend_render_property)
	pass

func tween_update(expend_render_property:Dictionary = {})->void:
	#只更新动画。
	pass

func _input(event)->void:
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
		# 检查当前悬停卡片是否有效或被拖拽
	if hovering_id >= 0 && (hovering_id >= area.card_pool.size() || area.card_pool[hovering_id].dragged):
		if hovering_id < area.card_pool.size():
			area.card_pool[hovering_id].hovering = false
		hovering_id = -1
	# 如果当前有悬停卡片但不再悬停或被拖拽
	if hovering_id != -1 && !area.card_pool[hovering_id].is_hovering(mouse_position):
		area.card_pool[hovering_id].hovering = false
		hovering_id = -1
	if hovering_id == -1:
		for i in range(area.card_pool.size()-1,-1,-1):
			if !area.card_pool[i].dragged && area.card_pool[i].is_hovering(mouse_position):
				hovering_id = i
				area.card_pool[hovering_id].hovering = true
				break
		return
	elif hovering_id < area.card_pool.size()-1:
		# 从当前悬停卡片上方开始检查
		var new_hover_id = -1
		for i in range(hovering_id + 1, area.card_pool.size()):
			if !area.card_pool[i].dragged:
				if area.card_pool[i].is_hovering(mouse_position):
					new_hover_id = i
				else:
					break#利用规范排序的性质
		if new_hover_id != -1:
			area.card_pool[hovering_id].hovering = false
			hovering_id = new_hover_id
			area.card_pool[hovering_id].hovering = true

func card_move()-> void:
	if area.card_pool.size() == 0||target_position.size()==0:
		return
	for i in range(0,area.card_pool.size()):
		var card_position = area.card_pool[i].position
		var _target_position = target_position[i]
		if !area.card_pool[i].dragged:
			GlobalUIAnimation.tween_animations(area.card_pool[i],{"position":_target_position})
	pass

func dragging_move(card)->void:
	pass

func _into_area()->void:
	pass
	
func _outto_area()->void:
	pass
