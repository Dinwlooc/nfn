extends Control

# 管理多个曲线箭头
var curve_managers: Array[CurveArrowManager] = []
var draw_cooldown: float = 0.0
var pending_draw: bool = false
var areahand: RenderAreaHand
var areatargets: RenderAreaPlayers
var is_dragging: bool = false
var in_area: bool = false
@export var control: RenderControl
const DRAW_COOLDOWN_DURATION: float = 0.35

func _ready() -> void:
	for i in range(1):  # 根据最大可能数量调整
		var manager: CurveArrowManager = CurveArrowManager.new()
		add_child(manager)
		curve_managers.append(manager)
	control.render_context.connect_renderarea(RenderArea.DefaultArea.HAND, connect_to_areahand)
	control.render_context.connect_renderarea(RenderArea.DefaultArea.PLAYERS, connect_to_areatargets)
	# 修改：连接新信号，使用 bind 传递拖拽状态
	control.render_context.dragging_started.connect(_on_dragged_update.bind(true))
	control.render_context.dragging_canceled.connect(_on_dragged_update.bind(false))

func _physics_process(delta: float) -> void:
	if draw_cooldown > 0:
		draw_cooldown -= delta
	if pending_draw && draw_cooldown <= 0:
		draw_arrow()
		return
	if is_dragging && not in_area:
		draw_arrow()

func connect_to_areahand(_areahand: RenderAreaHand) -> void:
	areahand = _areahand
	areahand.render_requested.connect(render_event_handler)
	areahand.tween_requested.connect(render_event_handler)

func connect_to_areatargets(_areatargets: RenderAreaPlayers) -> void:
	areatargets = _areatargets
	areatargets.render_requested.connect(render_event_handler)
	areatargets.tween_requested.connect(render_event_handler)

func draw_arrow() -> void:
	pending_draw = false
	var start_points: Array[Vector2] = get_start_point_array()
	if not in_area && not is_dragging:
		clear_arrow()
		return
	if start_points.is_empty():
		clear_arrow()
		return
	var end_items: Array[RenderItem] = areatargets.get_selected_items()
	if end_items.is_empty():
		clear_arrow()
		return
	var end_points: Array[Vector2] = get_end_point_array()
	if start_points.size() == 1 && end_items.size() >= 1:
		for i in min(end_items.size(), curve_managers.size()):
			var is_local: bool = (end_items[i] == areatargets.local_player)
			curve_managers[i].visible = true
			curve_managers[i].draw_curve(start_points[0], end_points[i], is_local)
	elif end_points.size() == 1 && start_points.size() >= 1:
		for i in min(start_points.size(), curve_managers.size()):
			curve_managers[i].visible = true
			curve_managers[i].draw_curve(start_points[i], end_points[0], false)

func clear_arrow() -> void:
	for manager in curve_managers:
		manager.clear_arrow()

# 修改：接收 item 和拖拽状态，item 参数在此未使用但保留以匹配信号
func _on_dragged_update(item: RenderItem, is_dragging: bool) -> void:
	clear_arrow()
	pending_draw = false
	self.is_dragging = is_dragging
	if not is_dragging && in_area:
		delay_draw_arrow()

func render_event_handler(render_event: RenderEvent) -> void:
	var event_type = render_event.get_type()
	if event_type == RenderEvent.DefaultType.OUTTO_AREA:
		in_area = false
		if is_dragging:
			return
		clear_arrow()
		pending_draw = false
		draw_cooldown = DRAW_COOLDOWN_DURATION
	elif event_type == RenderEvent.DefaultType.INTO_AREA:
		in_area = true
		if is_dragging:
			clear_arrow()
			return
		if draw_cooldown > 0:
			delay_draw_arrow()
		else:
			draw_arrow()
	elif event_type == RenderEvent.DefaultType.CARD_SELECTION_CHANGED:
		if is_dragging:
			return
		if draw_cooldown > 0:
			delay_draw_arrow()
		else:
			draw_arrow()

func delay_draw_arrow() -> void:
	draw_cooldown = DRAW_COOLDOWN_DURATION
	pending_draw = true

func get_start_point_array() -> Array[Vector2]:
	var array: Array[Vector2] = []
	if not areahand:
		return array
	var cards: Array[RenderItem] = areahand.get_selected_items()
	if cards:
		var item_size: Vector2 = cards[0].get_item_size()  # 同一区域卡牌大小一致
		array.append_array(cards.map(
			func(card: RenderItem) -> Vector2:
				return card.position + Vector2(0, -item_size.y)  # 手牌顶部中心
		))
	return array

func get_end_point_array() -> Array[Vector2]:
	var array: Array[Vector2] = []
	var cards: Array[RenderItem] = areatargets.get_selected_items()
	if cards:
		var item_size: Vector2 = cards[0].get_item_size()
		for card in cards:
			var pos: Vector2
			if card == areatargets.local_player:
				# 本地玩家：指向卡牌顶部中心
				pos = card.position + Vector2(item_size.x / 2.0, 0)
			else:
				# 其他玩家：指向卡牌底部中心
				pos = card.position + Vector2(item_size.x / 2.0, item_size.y)
			array.append(pos)
	return array
