## 手牌区面板，管理卡牌布局、排序、拖拽及操作按钮。
extends AreaFace

const HandSortManager = preload("hand_sort_manager.gd")
const HandDragManager = preload("hand_drag_manager.gd")
const HandAnimationManager = preload("hand_animation_manager.gd")

var original_position: Vector2
var original_size: Vector2
var area_target_position: Vector2
var area_target_size: Vector2
var total_scale_factor: float = 1.0
var current_card_tween: Tween = null
var current_drag_tween: Tween = null

var _sort_manager: HandSortManager = null
var _drag_manager: HandDragManager = null
var _anim_manager: HandAnimationManager = null

@onready var ui_container = $UIContainer
@onready var quick_sort_ui = $UIContainer/QuickSortUI
@onready var quick_sort_button = $UIContainer/QuickSortUI/QuickSortButton
@onready var play_card_ui = $UIContainer/PlayCardUI
@onready var play_card_button = $UIContainer/PlayCardUI/PlayCardButton
@onready var discard_cards_ui = $UIContainer/DiscardCardsUI
@onready var discard_button = $UIContainer/DiscardCardsUI/DiscardCardsButton
@onready var abandon_response_ui = $UIContainer/AbandonResponseUI
@onready var abandon_response_button = $UIContainer/AbandonResponseUI/AbandonResponseButton

## 初始化手牌区面板，设置管理器、请求区域、连接信号等。
func _ready() -> void:
	_sort_manager = HandSortManager.new()
	_drag_manager = HandDragManager.new()
	_anim_manager = HandAnimationManager.new()
	request_area(RenderArea.DefaultArea.HAND)
	original_position = global_position
	original_size = size
	area_target_position = original_position
	area_target_size = original_size
	quick_sort_button.pressed.connect(_on_quick_sort_button_pressed)
	play_card_button.pressed.connect(_on_play_card_button_pressed)
	discard_button.pressed.connect(_on_discard_button_pressed)
	abandon_response_button.pressed.connect(_on_abandon_response_button_pressed)
	ui_container.hide()
	_update_total_scale_factor()
	play_card_ui.visible = false
	discard_cards_ui.visible = false
	if area and area.items_pool.size() > 0:
		_request_sort()

## 根据卡牌数量更新总缩放因子。
## @internal
func _update_total_scale_factor() -> void:
	if not area:
		return
	var count: int = area.items_pool.size()
	total_scale_factor = UIAnimationUtils.compute_scale_factor(count, 8, 24, 0.75, 1.0)
## 物理帧处理，驱动卡牌移动动画与拖拽交换检测。
## @override
func _physics_process(delta: float) -> void:
	if in_area:
		_anim_manager.card_move_expand(area.items_pool)
		return
	if Engine.get_process_frames() % 2 == 0:
		_anim_manager.card_move_expand(area.items_pool)
	if _drag_manager.pending_swap and _drag_manager.can_swap_immediately(Time.get_ticks_msec()):
		try_dragging_move()
		_drag_manager.clear_pending()
## 处理渲染事件更新，触发排序、缩放更新及坐标计算。
## @hook @side_effect
func render_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	var event_type: StringName = render_event.get_type()
	if event_type == RenderEvent.DefaultType.CARD_ADD:
		_sort_manager.increment_counter()
		_update_total_scale_factor()
		if _sort_manager.should_auto_sort():
			_request_sort()
	elif event_type == RenderEvent.DefaultType.CARD_REMOVE:
		_update_total_scale_factor()
	if area and area.items_pool.size() > 0:
		var scaled_card_size: Vector2 = Vector2(
			area.items_pool[0].size.x * total_scale_factor,
			area.items_pool[0].size.y * total_scale_factor
		)
		var virtual_pos: Vector2 = area_target_position - scaled_card_size / 2.0
		var virtual_size: Vector2 = area_target_size
		target_position = UIAnimationUtils.generate_coordinates(virtual_pos, virtual_size, area.items_pool.size())
	tween_update(render_event)
## 处理与 Tween 相关的更新，包括交换事件和 UI 选择状态。
## @hook @side_effect
func tween_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	var event_type: StringName = render_event.get_type()
	if event_type == RenderEvent.DefaultType.SWAP_CARD:
		_sort_manager.increment_counter()
	if event_type == RenderEvent.DefaultType.CARD_SELECTION_CHANGED:
		_update_selection_ui()
	card_move(render_event)
## 根据当前选中卡牌更新操作按钮的可见性。
## @internal
func _update_selection_ui() -> void:
	if not area:
		return
	var has_selection: bool = not area.get_selected_items().is_empty()
	play_card_ui.visible = has_selection
	discard_cards_ui.visible = has_selection
## 进入区域时的行为，扩展面板并显示 UI。
## @override @side_effect
func _into_area() -> void:
	super._into_area()
	area_target_position = original_position - Vector2(0, 180.0)
	area_target_size = original_size + Vector2(0, 180.0)
	UIAnimationUtils.tween_rect(self,area_target_position,area_target_size)
	ui_container.show()
	if area:
		area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.INTO_AREA))
## 离开区域时的行为，收缩面板并隐藏 UI。
## @override @side_effect
func _outto_area() -> void:
	super._outto_area()
	area_target_position = original_position
	area_target_size = original_size
	UIAnimationUtils.tween_rect(self,area_target_position,area_target_size)
	ui_container.hide()
	if area:
		area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.OUTTO_AREA))
## 创建主 Tween 驱动所有卡牌位置和缩放动画。
## @delegates
func card_move(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	if not area or area.items_pool.is_empty() or target_position.is_empty():
		return
	var master_tween: Tween = create_tween()
	_anim_manager.card_move(master_tween, area.items_pool, target_position, total_scale_factor, render_event)
	if current_card_tween:
		current_card_tween.kill()
	current_card_tween = master_tween
## 拖拽卡牌时跟随鼠标移动，并触发交换检测。
## @delegates
func dragging_move(card: RenderItem) -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var drag_tween: Tween = create_tween()
	_anim_manager.dragging_move(drag_tween, card, mouse_pos, total_scale_factor)
	if current_drag_tween:
		current_drag_tween.kill()
	current_drag_tween = drag_tween
	swap_cards(card)
## 尝试将拖拽卡牌与当前悬停卡牌交换。
## @delegates
func swap_cards(drag_card: RenderItem) -> void:
	var current_time_ms: int = Time.get_ticks_msec()
	var success: bool = _drag_manager.try_swap(drag_card, hovering_card, area, current_time_ms)
	if success:
		hovering_card = null
## 通过排序管理器发起排序请求，并控制按钮状态。
## @internal
func _request_sort() -> void:
	_sort_manager.request_sort(area,
		func(): quick_sort_button.disabled = true,
		func(): quick_sort_button.disabled = false
	)
## 快速排序按钮点击处理。
## @side_effect
func _on_quick_sort_button_pressed() -> void:
	if not _sort_manager.can_manual_sort():
		return
	_request_sort()
## 出牌按钮点击处理。
## @side_effect
func _on_play_card_button_pressed() -> void:
	var op_manager: OperationManager = render_context.get_operation_manager()
	if not op_manager:
		return
	var event: RenderEvent = op_manager.upload_play_card()
	_handle_operation_event(event)
## 弃牌按钮点击处理。
## @side_effect
func _on_discard_button_pressed() -> void:
	if not render_context:
		return
	var op_manager: OperationManager = render_context.get_operation_manager()
	if not op_manager:
		return
	var event: RenderEvent = op_manager.upload_discard_cards()
	_handle_operation_event(event)
## 放弃响应按钮点击处理。
## @side_effect
func _on_abandon_response_button_pressed() -> void:
	if not render_context:
		return
	var op_manager: OperationManager = render_context.get_operation_manager()
	if not op_manager:
		return
	var event: RenderEvent = op_manager.upload_abandon_response()
	_handle_operation_event(event)
## 处理操作管理器返回的事件，检查状态并打印失败信息。
## @internal
func _handle_operation_event(event: RenderEvent) -> void:
	var status: int = event.config.get(&"status", -1)
	if status == OperationManager.RequestStatus.SUCCESS:
		return
	print("操作失败，状态码: ", status)
