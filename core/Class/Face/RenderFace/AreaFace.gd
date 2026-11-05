## 区域表现基类：绑定一个 [RenderArea]，把区域的渲染/补间信号路由到子类钩子，并提供悬停与拖拽的公共入口。补间槽位与已提交状态由子类持有。
extends Control
class_name AreaFace

#==vars==
## 当前鼠标悬停的卡牌（只读引用）
var hovering_card: RenderItem = null
## 目标位置数组（由子类计算，供布局补间消费）
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

#==signals==
## 进入区域时触发的广播信号
## @emitter
signal into_area
## 离开区域时触发的广播信号
## @emitter
signal outto_area

#==binding==
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
## 向渲染上下文注册区域变更回调。
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
## 连接到新区域，订阅区域与卡牌事件。
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

#==queries==
## 统计未被拖拽的卡牌数：排布补间会跳过拖拽中的卡，全拖时补间为空。
## @pure
func count_draggable_cards() -> int:
	if not area:
		return 0
	var count: int = 0
	for card in area.items_pool:
		if not card.dragged:
			count += 1
	return count
#==hooks==
## 渲染更新钩子，由区域的数据更新触发。
## @hook @delegates(tween_update)
func render_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	tween_update(render_event)
## 补间更新钩子，由区域信号与逐帧路径普遍触发。子类在此采集目标状态并提交差量。
## @hook
func tween_update(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	pass
## 卡牌布局补间钩子（子类实现具体动画），携带触发本次布局的渲染事件。
## @hook
func card_move(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	pass
## 拖拽跟随钩子（子类实现具体跟随）。
## @hook
func dragging_move(_card: RenderItem) -> void:
	pass
## 区域上下文就绪钩子（同时作为 context_ready 信号的监听回调）。
## @hook @signal_listener
func _on_context_ready() -> void:
	pass
## 进入区域的行为钩子：只做面板内部实现，不必经过信号。
## @hook
func on_into_area() -> void:
	pass
## 离开区域的行为钩子：只做面板内部实现，不必经过信号。
## @hook
func on_outto_area() -> void:
	pass

#==signals_in==
## 卡牌移除回调：断开该卡牌的鼠标信号。
## @signal_listener
func _on_item_removed(card: RenderItem) -> void:
	disconnect_card_signals(card)
## 连接单张卡牌的鼠标信号。
## @signal_listener
func connect_cards_signals(card: RenderItem) -> void:
	card.mouse_entered_item.connect(_on_card_mouse_entered)
	card.mouse_exited_item.connect(_on_card_mouse_exited)
## 断开单张卡牌的鼠标信号，并清理悬停状态。
## @signal_listener
func disconnect_card_signals(card: RenderItem) -> void:
	if hovering_card == card:
		card.set_hovering(false)
		hovering_card = null
	card.mouse_entered_item.disconnect(_on_card_mouse_entered)
	card.mouse_exited_item.disconnect(_on_card_mouse_exited)
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
	if hovering_card != card:
		return
	card.set_hovering(false)
	hovering_card = null

#==input==
## 输入事件处理：检测鼠标进入/离开，并触发拖拽更新。
## @override
func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	try_dragging_move()
	var mouse_position: Vector2 = get_local_mouse_position()
	var inside: bool = Rect2(Vector2.ZERO, size).has_point(mouse_position)
	if inside == in_area:
		return
	in_area = inside
	if inside:
		emit_into_area()
		on_into_area()
		return
	emit_outto_area()
	on_outto_area()
## 尝试处理当前拖拽的卡牌移动（转发给 dragging_move）。
## @delegates(dragging_move)
func try_dragging_move() -> bool:
	if not area:
		return false
	var context: RenderContext = area.render_context
	if not context:
		return false
	var card: RenderItem = context.get_dragged_card()
	if not card or card.area_name != area.get_area_name():
		return false
	dragging_move(card)
	return true

#==emit==
## 进入面板区域时发射 into_area 信号。
## @atomic @emitter
func emit_into_area() -> void:
	into_area.emit()
## 离开面板区域时发射 outto_area 信号。
## @atomic @emitter
func emit_outto_area() -> void:
	outto_area.emit()
