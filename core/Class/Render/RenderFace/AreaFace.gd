extends Control
class_name AreaFace

var hovering_card: RenderItem = null
var target_position: PackedVector2Array
var area: RenderArea
var in_area: bool = false
var render_context: RenderContext
var _requested_area_name: StringName
var _requested_player_id: int = RenderContext.PUBLIC_PLAYER_ID
var _area_requested: bool = false
signal into_area
signal outto_area

func set_render_context(p_render_context: RenderContext) -> void:
	if render_context and _area_requested:
		render_context.disconnect_renderarea(_requested_area_name, self._connect_to_area, _requested_player_id)
	render_context = p_render_context
	if _area_requested and render_context:
		_register_area_callback()
# 请求区域：子类调用此方法以自动连接指定区域
func request_area(area_name: StringName, player_id: int = RenderContext.PUBLIC_PLAYER_ID) -> void:
	if _area_requested:
		if render_context:
			render_context.disconnect_renderarea(_requested_area_name, self._connect_to_area, _requested_player_id)
		_area_requested = false
	_requested_area_name = area_name
	_requested_player_id = player_id
	_area_requested = true
	if render_context:
		_register_area_callback()
# 将回调注册到 RenderContext
func _register_area_callback() -> void:
	render_context.connect_renderarea(_requested_area_name, self._connect_to_area, _requested_player_id)
# 实际连接区域信号的方法
func _connect_to_area(target_area: RenderArea) -> void:
	if area == target_area:
		return
	_disconnect_from_current_area()
	area = target_area
	area.render_requested.connect(render_update)
	area.tween_requested.connect(tween_update)
	area.items_added.connect(connect_cards_signals)
	area.items_removed.connect(_on_item_removed)
	area.context_ready.connect(_on_context_ready)

func _disconnect_from_current_area() -> void:
	if not area:
		return
	if area.items_removed.is_connected(_on_item_removed):
		area.items_removed.disconnect(_on_item_removed)
	for child in area.get_children():
		if child is RenderItem:
			disconnect_card_signals(child)
	if area.render_requested.is_connected(render_update):
		area.render_requested.disconnect(render_update)
	if area.tween_requested.is_connected(tween_update):
		area.tween_requested.disconnect(tween_update)
	if area.items_added.is_connected(connect_cards_signals):
		area.items_added.disconnect(connect_cards_signals)
	if area.context_ready.is_connected(_on_context_ready):
		area.context_ready.disconnect(_on_context_ready)
	area = null

func _exit_tree() -> void:
	if render_context and _area_requested:
		render_context.disconnect_renderarea(_requested_area_name,self._connect_to_area, _requested_player_id)
	_disconnect_from_current_area()

func _on_item_removed(card: RenderItem) -> void:
	disconnect_card_signals(card)

func render_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	tween_update(render_event)

func tween_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	pass

func _input(event) -> void:
	if event is InputEventMouseMotion:
		try_dragging_move()
		var mouse_position = get_local_mouse_position()
		if Rect2(Vector2.ZERO, size).has_point(mouse_position):
			if !in_area:
				_into_area()
			in_area = true
		else:
			if in_area:
				_outto_area()
			in_area = false

# 拖拽移动时需确保 area 有效
func try_dragging_move() -> bool:
	if not area:
		return false
	var context: RenderContext = area.render_context
	var card: RenderItem = context.get_dragged_card()
	if context and card and card.area_name == area.get_area_name():
		dragging_move(card)
		return true
	return false

# 连接卡片信号
func connect_cards_signals(card: RenderItem) -> void:
	if not card.mouse_entered.is_connected(_on_card_mouse_entered):
		card.mouse_entered.connect(_on_card_mouse_entered.bind(card))
	if not card.mouse_exited.is_connected(_on_card_mouse_exited):
		card.mouse_exited.connect(_on_card_mouse_exited.bind(card))

# 断开卡片信号（可多次调用，内部会做检查）
func disconnect_card_signals(card: RenderItem) -> void:
	if hovering_card == card:
		card.set_hovering(false)
		hovering_card = null

	if card.mouse_entered.is_connected(_on_card_mouse_entered):
		card.mouse_entered.disconnect(_on_card_mouse_entered)
	if card.mouse_exited.is_connected(_on_card_mouse_exited):
		card.mouse_exited.disconnect(_on_card_mouse_exited)

func _on_card_mouse_entered(card: RenderItem) -> void:
	if card.dragged:
		return
	if hovering_card and hovering_card != card:
		card.set_hovering(false)
	hovering_card = card
	card.set_hovering(true)

func _on_card_mouse_exited(card: RenderItem) -> void:
	if hovering_card == card:
		card.set_hovering(false)
		hovering_card = null

func card_move() -> void:
	pass

func dragging_move(_card: RenderItem) -> void:
	pass

func _into_area() -> void:
	into_area.emit()

func _outto_area() -> void:
	outto_area.emit()

func _on_context_ready() -> void:
	pass
