extends Control
class_name AreaFace

## 当前鼠标悬停的卡牌（只读引用）
var hovering_card: RenderItem = null
## 目标位置数组（由子类计算）
var target_position: PackedVector2Array
## 当前绑定的渲染区域
var area: RenderArea
## 鼠标是否位于面板内
var in_area: bool = false
## 渲染上下文
var render_context: RenderContext
## 请求的区域名称（内部状态）
var _requested_area_name: StringName
## 请求的玩家 ID（内部状态）
var _requested_player_id: int = RenderContext.PUBLIC_PLAYER_ID
## 是否已请求区域（内部状态）
var _area_requested: bool = false
## 区域变更回调引用（内部状态）
var _area_changed_callback: Callable
## 进入区域时触发的广播信号
## @emitter
signal into_area
## 离开区域时触发的广播信号
## @emitter
signal outto_area

## 设置渲染上下文，并重新连接区域回调。
## @side_effect
func set_render_context(p_render_context: RenderContext) -> void:
	if render_context and _area_requested:
		render_context.disconnect_renderarea(_requested_area_name, _area_changed_callback, _requested_player_id)
	render_context = p_render_context
	if _area_requested and render_context:
		_register_area_callback()
## 请求绑定指定区域，断开旧连接并建立新连接。
## @side_effect
func request_area(area_name: StringName, player_id: int = RenderContext.PUBLIC_PLAYER_ID) -> void:
	if _area_requested:
		if render_context:
			render_context.disconnect_renderarea(_requested_area_name, _area_changed_callback, _requested_player_id)
		_area_requested = false
	_requested_area_name = area_name
	_requested_player_id = player_id
	_area_requested = true
	_area_changed_callback = _on_area_changed
	if render_context:
		_register_area_callback()
## 向渲染上下文注册区域变更回调（内部）。
## @signal_listener
func _register_area_callback() -> void:
	render_context.connect_renderarea(_requested_area_name, _area_changed_callback, _requested_player_id)
## 区域变更回调：切换绑定的区域，连接/断开信号。
## @signal_listener
func _on_area_changed(new_area: RenderArea, old_area: RenderArea) -> void:
	if old_area:
		_disconnect_from_area(old_area)
	if not new_area:
		area = null
		return
	_connect_to_area(new_area)
## 连接到新区域，订阅所有卡牌事件。
## @signal_listener
func _connect_to_area(target_area: RenderArea) -> void:
	if area == target_area:
		return
	if area:
		_disconnect_from_area(area)
	area = target_area
	area.render_requested.connect(render_update)
	area.tween_requested.connect(tween_update)
	area.items_added.connect(connect_cards_signals)
	area.items_removed.connect(_on_item_removed)
	area.context_ready.connect(_on_context_ready)
	#for child in area.get_children():
		#if child is RenderItem:
			#connect_cards_signals(child)
## 断开与旧区域的所有信号连接。
## @signal_listener
func _disconnect_from_area(target_area: RenderArea) -> void:
	if not target_area:
		return
	target_area.items_removed.disconnect(_on_item_removed)
	for child in target_area.get_children():
		if child is RenderItem:
			disconnect_card_signals(child)
	target_area.render_requested.disconnect(render_update)
	target_area.tween_requested.disconnect(tween_update)
	target_area.items_added.disconnect(connect_cards_signals)
	target_area.context_ready.disconnect(_on_context_ready)
## 节点退出场景树时清理区域绑定与信号。
## @override
func _exit_tree() -> void:
	if render_context and _area_requested:
		render_context.disconnect_renderarea(_requested_area_name, _area_changed_callback, _requested_player_id)
	if area:
		_disconnect_from_area(area)
		area = null
## 卡牌移除时的回调，断开其信号。
## @signal_listener
func _on_item_removed(card: RenderItem) -> void:
	disconnect_card_signals(card)
## 渲染更新钩子，由区域触发。默认调用 tween_update。
## @hook
func render_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	tween_update(render_event)
## Tween 更新钩子，由区域触发。子类可重写。
## @hook
func tween_update(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	pass
## 输入事件处理：检测鼠标进入/离开，并触发拖拽更新。
## @side_effect
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		try_dragging_move()
		var mouse_position: Vector2 = get_local_mouse_position()
		if Rect2(Vector2.ZERO, size).has_point(mouse_position):
			if not in_area:
				in_area = true
				_into_area()
		else:
			if in_area:
				in_area = false
				_outto_area()
## 尝试处理当前拖拽的卡牌移动（转发给 dragging_move）。
## @delegates
func try_dragging_move() -> bool:
	if not area:
		return false
	var context: RenderContext = area.render_context
	var card: RenderItem = context.get_dragged_card()
	if context and card and card.area_name == area.get_area_name():
		dragging_move(card)
		return true
	return false
## 连接单张卡牌的鼠标信号。
## @signal_listener
func connect_cards_signals(card: RenderItem) -> void:
	card.mouse_entered.connect(_on_card_mouse_entered.bind(card))
	card.mouse_exited.connect(_on_card_mouse_exited.bind(card))
## 断开单张卡牌的鼠标信号，并清理悬停状态。
## @signal_listener
func disconnect_card_signals(card: RenderItem) -> void:
	if hovering_card == card:
		card.set_hovering(false)
		hovering_card = null
	card.mouse_entered.disconnect(_on_card_mouse_entered)
	card.mouse_exited.disconnect(_on_card_mouse_exited)
## 卡牌鼠标进入回调：更新悬停状态。
## @signal_listener
func _on_card_mouse_entered(card: RenderItem) -> void:
	if card.dragged:
		return
	if hovering_card and hovering_card != card:
		card.set_hovering(false)
	hovering_card = card
	card.set_hovering(true)
## 卡牌鼠标离开回调：清除悬停状态。
## @signal_listener
func _on_card_mouse_exited(card: RenderItem) -> void:
	if hovering_card == card:
		card.set_hovering(false)
		hovering_card = null
## 卡牌移动钩子（子类实现具体动画）。
## @hook
func card_move() -> void:
	pass
## 拖拽移动钩子（子类实现具体跟随）。
## @hook
func dragging_move(_card: RenderItem) -> void:
	pass
## 进入面板区域时触发，发射 into_area 信号。
## @emitter
func _into_area() -> void:
	into_area.emit()
## 离开面板区域时触发，发射 outto_area 信号。
## @emitter
func _outto_area() -> void:
	outto_area.emit()
## 区域上下文就绪钩子（子类可按需重写）。
## @hook
func _on_context_ready() -> void:
	pass
