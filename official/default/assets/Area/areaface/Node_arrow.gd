extends Control

# 管理多个曲线箭头
var curve_managers: Array[CurveArrowManager] = []
var draw_cooldown: float = 0.0
var pending_draw = false
var areahand:RenderAreaHand
var areatargets:RenderAreaTargets
var is_can_drag:bool = true
@export var control:RenderControl
const DRAW_COOLDOWN_DURATION: float = 0.35

func _ready() -> void:
	for i in range(1):  # 根据最大可能数量调整
		var manager = CurveArrowManager.new()
		add_child(manager)
		curve_managers.append(manager)
	control.render_context.connect_renderarea(RenderArea.DefaultArea.HAND,connect_to_areahand)
	control.render_context.connect_renderarea(RenderArea.DefaultArea.PLAYERS,connect_to_areatargets)
	control.render_context.dragged_update.connect(_on_dragged_update)
	GlobalRegistry.connect_singleton(GlobalRegistry.RENDER_CONTROL_TYPE,connect_to_control)

func _physics_process(delta: float) -> void:
	if draw_cooldown > 0:
		draw_cooldown -= delta
		if pending_draw && draw_cooldown <= 0:
			draw_arrow()

func connect_to_areahand(_areahand:RenderAreaHand)->void:
	areahand = _areahand
	areahand.selected.connect(draw_arrow)
	areahand.render_requested.connect(render_event_handler)
	areahand.tween_requested.connect(render_event_handler)
func connect_to_areatargets(_areatargets:RenderAreaTargets)->void:
	areatargets = _areatargets
	areatargets.selected.connect(draw_arrow)
	areatargets.render_requested.connect(render_event_handler)
	areatargets.tween_requested.connect(render_event_handler)
func connect_to_control(control:RenderControl)->void:
	control.render_context.dragged_update.connect(clear_arrow)

func draw_arrow() -> void:
	pending_draw = false
	clear_arrow()
	if !is_can_drag:
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

func _on_dragged_update(is_card:bool):
	if is_card:
		is_can_drag = false
		clear_arrow()
	else:
		is_can_drag = true

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
	var cards:Array[RenderItem] = areahand.get_selected_cards()
	if cards:
		var item_size = cards[0].get_item_size() #规范条件，同一区域的卡牌大小一致
		array.append_array(cards.map(
		func(card:RenderItem) -> Vector2:
			return card.position + Vector2(0, - item_size.y)
			))
	return array

func get_end_point_array() -> Array[Vector2]:
	var array:Array[Vector2] = []
	var cards:Array[RenderItem] = areatargets.get_selected_cards()
	if cards:
		var item_size = cards[0].get_item_size() #规范条件，同一区域的卡牌大小一致
		array.append_array(cards.map(
			func(card:RenderItem) -> Vector2:
				return card.position + Vector2(item_size.x / 2.0, item_size.y)
				))
	return array
