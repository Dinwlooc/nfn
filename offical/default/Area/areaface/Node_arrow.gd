extends Control

# 管理多个曲线箭头
var curve_managers: Array[CurveArrowManager] = []
var draw_cooldown: float = 0.0
var pending_draw = false
const DRAW_COOLDOWN_DURATION: float = 0.35
const AREA_HAND:StringName = &"areahand"
const AREA_TARGETS:StringName = &"areatargets"

func _ready() -> void:
	for i in range(1):  # 根据最大可能数量调整
		var manager = CurveArrowManager.new()
		add_child(manager)
		curve_managers.append(manager)
	call_deferred(&"connect_signal")
	
func _physics_process(delta: float) -> void:
	if draw_cooldown > 0:
		draw_cooldown -= delta
		if pending_draw && draw_cooldown <= 0:
			draw_arrow()

func connect_signal()->void:
	var areahand:RenderArea = GlobalConsole.get_renderarea(AREA_HAND)
	if areahand:
		areahand.selected.connect(draw_arrow)
		areahand.render_requested.connect(render_event_handler)
		areahand.tween_requested.connect(render_event_handler)
	var areatargets = GlobalConsole.get_renderarea(AREA_TARGETS)
	if areatargets:
		areatargets.selected.connect(draw_arrow)
		areatargets.render_requested.connect(render_event_handler)
		areatargets.tween_requested.connect(render_event_handler)
	GlobalConsole.global_dragged.connect(clear_arrow)
	pass

func draw_arrow() -> void:
	pending_draw = false
	clear_arrow()
	if GlobalConsole.card_on_drag:
		return
	var start_points = get_start_point_array()
	if start_points.is_empty():
		return
	var end_points = get_end_point_array()
	if end_points.is_empty():
		return
	if start_points.size() == 1 && end_points.size() >= 1:
		for i in min(end_points.size(),curve_managers.size()):
			curve_managers[i].visible = true
			curve_managers[i].draw_curve(start_points[0], end_points[i])
	elif end_points.size() == 1 && start_points.size() >= 1:
		for i in min(start_points.size(),curve_managers.size()):
			curve_managers[i].visible = true
			curve_managers[i].draw_curve(start_points[i], end_points[0])

func clear_arrow()->void:
	for manager in curve_managers:
		manager.clear_arrow()

func render_event_handler(render_event:RenderEvent):
	if render_event.type == RenderEvent.DefaultType.OUTTO_AREA:
		clear_arrow()
		pending_draw = false
	else:
		delay_draw_arrow()

func delay_draw_arrow()->void:
	draw_cooldown = DRAW_COOLDOWN_DURATION
	pending_draw = true
	pass

func get_start_point_array() -> Array[Vector2]:
	var array:Array[Vector2] = []
	var cards:Array[RenderCard] = GlobalConsole.get_renderarea(AREA_HAND).get_selected_cards()
	if cards:
		var card_size = cards[0].get_face_size() #规范条件，同一区域的卡牌大小一致
		array.append_array(cards.map(
		func(card:RenderCard) -> Vector2:
			return card.position + Vector2(0, - card_size.y)
			))
	return array

func get_end_point_array() -> Array[Vector2]:
	var array:Array[Vector2] = []
	var cards:Array[RenderCard] = GlobalConsole.get_renderarea(AREA_TARGETS).get_selected_cards()
	if cards:
		var card_size = cards[0].get_face_size() #规范条件，同一区域的卡牌大小一致
		array.append_array(cards.map(
			func(card:RenderCard) -> Vector2:
				return card.position + Vector2(card_size.x / 2.0, card_size.y)
				))
	return array
