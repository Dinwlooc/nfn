## 手牌区面板：管理卡牌布局、排序、拖拽及操作按钮。
extends AreaFace

#==vars==
## 面板原始位置
var original_position: Vector2
## 面板原始尺寸
var original_size: Vector2
## 排列目标区域中心
var area_target_position: Vector2
## 排列目标区域尺寸
var area_target_size: Vector2
## 手牌整体缩放系数
var total_scale_factor: float = 1.0
## 卡牌排布补间槽位（同一时刻只保留一条）
var layout_tween: Tween = null
## 拖拽跟随补间槽位（同一时刻只保留一条）
var drag_tween: Tween = null
## 面板自身展开/收起补间槽位（同一时刻只保留一条）
var panel_tween: Tween = null
## 排序管理器实例
var _sort_manager: HandSortManager = null
## 拖拽管理器实例
var _drag_manager: HandDragManager = null
## 已提交的面板展开状态（用于差量判定）
var _applied_panel_expanded: bool = false
## 动画管理器实例
var _anim_manager: HandAnimationManager = null

#==consts==
## 手牌排序管理器脚本
const HandSortManager = preload("hand_sort_manager.gd")
## 手牌拖拽管理器脚本
const HandDragManager = preload("hand_drag_manager.gd")
## 手牌动画管理器脚本
const HandAnimationManager = preload("hand_animation_manager.gd")

#==nodes==
## 操作按钮容器
@onready var ui_container: Control = $UIContainer
## 快捷排序按钮容器
@onready var quick_sort_ui: Control = $UIContainer/QuickSortUI
## 快捷排序按钮
@onready var quick_sort_button: Button = $UIContainer/QuickSortUI/QuickSortButton
## 出牌按钮容器
@onready var play_card_ui: Control = $UIContainer/PlayCardUI
## 出牌按钮
@onready var play_card_button: Button = $UIContainer/PlayCardUI/PlayCardButton
## 弃牌按钮容器
@onready var discard_cards_ui: Control = $UIContainer/DiscardCardsUI
## 弃牌按钮
@onready var discard_button: Button = $UIContainer/DiscardCardsUI/DiscardCardsButton
## 放弃响应按钮容器
@onready var abandon_response_ui: Control = $UIContainer/AbandonResponseUI
## 放弃响应按钮
@onready var abandon_response_button: Button = $UIContainer/AbandonResponseUI/AbandonResponseButton

#==lifecycle==
## 就绪：初始化管理器、请求区域、连接按钮并恢复初始布局。
## @override
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
## 物理帧：悬停时每帧驱动正弦浮动，否则隔帧驱动；并处理延迟交换检测。
## @override
func _physics_process(_delta: float) -> void:
	if in_area:
		_anim_manager.card_move_expand(area.items_pool)
		return
	if Engine.get_process_frames() % 2 == 0:
		_anim_manager.card_move_expand(area.items_pool)
	if _drag_manager.pending_swap and _drag_manager.can_swap_immediately(Time.get_ticks_msec()):
		try_dragging_move()
		_drag_manager.clear_pending()

#==hooks==
## 渲染更新：归约卡牌数量与事件类型，重算排列坐标后提交补间。
## @override
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
## 补间更新：处理交换计数与选择 UI，再提交卡牌排布。
## @override
func tween_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	var event_type: StringName = render_event.get_type()
	if event_type == RenderEvent.DefaultType.SWAP_CARD:
		_sort_manager.increment_counter()
	if event_type == RenderEvent.DefaultType.CARD_SELECTION_CHANGED:
		_update_selection_ui()
	card_move(render_event)
## 进入区域：显示操作 UI 并提交面板展开态。
## @override
func on_into_area() -> void:
	ui_container.show()
	_submit_panel_expanded(true)
	if area:
		area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.INTO_AREA))
## 离开区域：隐藏操作 UI 并提交面板收起态。
## @override
func on_outto_area() -> void:
	ui_container.hide()
	_submit_panel_expanded(false)
	if area:
		area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.OUTTO_AREA))

#==tween==
## 卡牌排布：按目标快照提交排布补间；全拖或空池由卫语句拦住，不建补间。
## @atomic
func card_move(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	if not area or area.items_pool.is_empty() or target_position.is_empty():
		return
	if count_draggable_cards() == 0:
		return
	var master_tween: Tween = create_tween()
	HandAnimationManager.do_card_layout(master_tween, area.items_pool, target_position, total_scale_factor)
	if render_event.get_type() == RenderEvent.DefaultType.SWAP_CARD:
		HandAnimationManager.do_swap_effect(master_tween, area.items_pool, target_position, total_scale_factor)
	master_tween.chain()
	HandAnimationManager.do_layout_reset(master_tween, area.items_pool, total_scale_factor)
	layout_tween = UIAnimationUtils.replace_tween(layout_tween, master_tween)
## 拖拽跟随：提交跟随补间并触发交换检测（单槽位提交）。
## @side_effect
func dragging_move(card: RenderItem) -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var next_drag_tween: Tween = create_tween()
	HandAnimationManager.do_drag_follow(next_drag_tween, card, mouse_pos, total_scale_factor)
	drag_tween = UIAnimationUtils.replace_tween(drag_tween, next_drag_tween)
	swap_cards(card)
## 面板展开：按目标展开状态提交面板几何补间（单槽位提交）。
## @atomic
func tween_panel(expanded: bool) -> void:
	area_target_position = original_position - Vector2(0, 180.0) if expanded else original_position
	area_target_size = original_size + Vector2(0, 180.0) if expanded else original_size
	var tween: Tween = create_tween()
	UIAnimationUtils.do_rect(tween, self, area_target_position, area_target_size)
	panel_tween = UIAnimationUtils.replace_tween(panel_tween, tween)

#==internal==
## 根据卡牌数量更新总缩放因子。
## @internal
func _update_total_scale_factor() -> void:
	if not area:
		return
	var count: int = area.items_pool.size()
	total_scale_factor = UIAnimationUtils.compute_scale_factor(count, 8, 24, 0.75, 1.0)
## 面板展开态差量提交：状态未变则早退。
## @internal
func _submit_panel_expanded(expanded: bool) -> void:
	if expanded == _applied_panel_expanded:
		return
	_applied_panel_expanded = expanded
	tween_panel(expanded)
## 根据当前选中卡牌更新操作按钮的可见性。
## @internal
func _update_selection_ui() -> void:
	if not area:
		return
	var has_selection: bool = not area.get_selected_items().is_empty()
	play_card_ui.visible = has_selection
	discard_cards_ui.visible = has_selection
## 尝试将拖拽卡牌与当前悬停卡牌交换。
## @side_effect
func swap_cards(drag_card: RenderItem) -> void:
	var current_time_ms: int = Time.get_ticks_msec()
	var success: bool = _drag_manager.try_swap(drag_card, hovering_card, area, current_time_ms)
	if success:
		hovering_card = null
## 发起排序请求，并控制按钮状态。
## @internal
func _request_sort() -> void:
	_sort_manager.request_sort(area,
		func(): quick_sort_button.disabled = true,
		func(): quick_sort_button.disabled = false
	)
## 处理操作管理器返回的事件，检查状态并打印失败信息。
## @internal
func _handle_operation_event(event: RenderEvent) -> void:
	var status: int = event.config.get(&"status", -1)
	if status == OperationManager.RequestError.OK:
		return
	print("操作失败，状态码: ", status)

#==signals_in==
## 快速排序按钮点击
## @signal_listener
func _on_quick_sort_button_pressed() -> void:
	if not _sort_manager.can_manual_sort():
		return
	_request_sort()
## 出牌按钮点击
## @signal_listener
func _on_play_card_button_pressed() -> void:
	var op_manager: OperationManager = render_context.get_operation_manager()
	if not op_manager:
		return
	var event: RenderEvent = op_manager.upload_play_card()
	_handle_operation_event(event)
## 弃牌按钮点击
## @signal_listener
func _on_discard_button_pressed() -> void:
	if not render_context:
		return
	var op_manager: OperationManager = render_context.get_operation_manager()
	if not op_manager:
		return
	var event: RenderEvent = op_manager.upload_discard_cards()
	_handle_operation_event(event)
## 放弃响应按钮点击
## @signal_listener
func _on_abandon_response_button_pressed() -> void:
	if not render_context:
		return
	var op_manager: OperationManager = render_context.get_operation_manager()
	if not op_manager:
		return
	var event: RenderEvent = op_manager.upload_abandon_response()
	_handle_operation_event(event)
