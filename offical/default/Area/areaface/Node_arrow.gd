extends Control

# 管理多个曲线箭头
var curve_managers: Array[CurveArrowManager] = []
var draw_cooldown: float = 0.0
var pending_draw = false
const DRAW_COOLDOWN_DURATION: float = 0.35
func _ready() -> void:
	for i in range(1):  # 根据最大可能数量调整
		var manager = CurveArrowManager.new()
		add_child(manager)
		curve_managers.append(manager)
	call_deferred("connect_signal")
	
func _physics_process(delta: float) -> void:
	if draw_cooldown > 0:
		draw_cooldown -= delta
		if pending_draw && draw_cooldown <= 0:
			draw_arrow()
			pending_draw = false

func connect_signal()->void:
	var areahand:RenderArea = GlobalConsole.get_renderarea("areahand")
	areahand.selected.connect(draw_arrow)
	areahand.render_requested.connect(delay_draw_arrow.unbind(1))
	areahand.tween_requested.connect(delay_draw_arrow.unbind(1))
	var areatargets = GlobalConsole.get_renderarea("areatargets")
	areatargets.selected.connect(draw_arrow)
	areatargets.render_requested.connect(delay_draw_arrow.unbind(1))
	areatargets.tween_requested.connect(delay_draw_arrow.unbind(1))
	GlobalConsole.global_dragged.connect(clear_arrow)
	pass

func draw_arrow() -> void:
	clear_arrow()
	if GlobalConsole.card_on_drag.get("card") != null:
		return
	var start_points = get_start_point_array()
	var end_points = get_end_point_array()
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

func delay_draw_arrow()->void:
	draw_cooldown = DRAW_COOLDOWN_DURATION
	pending_draw = true
	pass

func get_start_point_array() -> Array[Vector2]:
	var array:Array[Vector2] = []
	var cards:Array[RenderCard] = GlobalConsole.get_renderarea("areahand").get_selected_cards()
	if cards:
		array.append_array(cards.map(
		func(card:RenderCard) -> Vector2:
			return card.position + Vector2(0, - card.get_face_size().y)
			))
	return array

func get_end_point_array() -> Array[Vector2]:
	var array:Array[Vector2] = []
	var cards:Array[RenderCard] = GlobalConsole.get_renderarea("areatargets").get_selected_cards()
	if cards:
		array.append_array(cards.map(
			func(card:RenderCard) -> Vector2:
				return card.position + Vector2(card.get_face_size().x / 2.0, card.get_face_size().y)
				))
	return array
