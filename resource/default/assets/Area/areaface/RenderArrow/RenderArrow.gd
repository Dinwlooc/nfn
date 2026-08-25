## 动态箭头管理器：维护手牌箭头、玩家箭头、连接线，以及守区非我方牌到其所有者的指示线。
## 通过信号驱动更新，主循环使用状态机（等待→排列→绘制）轮询。
extends Control

# 导入内部依赖
const ArrowNode = preload("Arrow.gd")
const ArrowLine = preload("ArrowLine.gd")

# ==================== 常量 ====================
const HAND_AREA_NAME: StringName = RenderArea.DefaultArea.HAND
const PLAYERS_AREA_NAME: StringName = RenderArea.DefaultArea.PLAYERS
const DEFENCE_AREA_NAME: StringName = RenderArea.DefaultArea.DEFENCE
const CURVE_TESSELLATE_PRECISION: int = 5
const ACTIVATION_DELAY_MS: int = 250

## 主循环状态机
enum State { IDLE, WAITING, ARRANGING, DRAWING }

## 手牌箭头
var _hand_arrow: ArrowNode
## 玩家箭头
var _player_arrow: ArrowNode
## 主线连接线
var _line: ArrowLine
## 守区非我方牌指示线（无箭头）
var _enemy_line: ArrowLine
## 激活延迟时间戳（毫秒），仅在 WAITING 状态有意义
var _activation_timestamp: int = 0
## 曲线插值数组是否有效（无需重新计算）
var _line_curve_valid: bool = false
## 当前玩家箭头目标是否为本地玩家（影响曲线方向）
var _is_local_target: bool = false
var _is_dragging: bool = false
## 当前是否处于“连线区域”（影响线的绘制与生成）
var _in_area: bool = false
var _needs_redraw: bool = false
var _connected_areas: Array[RenderArea] = []
## 缓存：上次手牌箭头目标位置（INF 表示无缓存）
var _cached_hand_target: Vector2 = Vector2.INF
## 缓存：上次手牌箭头方向
var _cached_hand_dir: Vector2 = Vector2.DOWN
## 缓存：上次玩家箭头目标位置
var _cached_player_target: Vector2 = Vector2.INF
## 缓存：上次玩家箭头方向
var _cached_player_dir: Vector2 = Vector2.UP
## 当前选中的玩家及目标（用于主线目标解析）
var _target_player: RenderItem = null
var _target_item: RenderItem = null
## 标记敌方曲线是否已经更新（防止重复构建）
var _enemy_line_updated: bool = false

var render_context: RenderContext
@export var render_control: RenderControl
## 当前状态
var _state: State = State.IDLE

# ==================== 生命周期 ====================
func _ready() -> void:
	if not render_control:
		return
	render_context = render_control.render_context
	if not render_context:
		return
	_hand_arrow = ArrowNode.new()
	_player_arrow = ArrowNode.new()
	_line = ArrowLine.new()
	_enemy_line = ArrowLine.new()
	add_child(_hand_arrow)
	add_child(_player_arrow)
	_hand_arrow.hide_arrow()
	_player_arrow.hide_arrow()
	_enemy_line.kill_animation()
	render_context.connect_renderarea(HAND_AREA_NAME, _on_area_connected)
	render_context.connect_renderarea(PLAYERS_AREA_NAME, _on_area_connected)

func _process(_delta: float) -> void:
	match _state:
		State.IDLE:
			set_process(false)
			return
		State.WAITING:
			_waiting_process()
		State.ARRANGING:
			_arranging_process()
		State.DRAWING:
			_drawing_process()
	if _needs_redraw:
		_needs_redraw = false
		queue_redraw()

func _exit_tree() -> void:
	_cleanup_all()
	if not render_context:
		return
	render_context.disconnect_renderarea(HAND_AREA_NAME, _on_area_connected)
	render_context.disconnect_renderarea(PLAYERS_AREA_NAME, _on_area_connected)
	for area in _connected_areas:
		if area.render_requested.is_connected(_on_area_render_event):
			area.render_requested.disconnect(_on_area_render_event)
		if area.tween_requested.is_connected(_on_area_render_event):
			area.tween_requested.disconnect(_on_area_render_event)
	_connected_areas.clear()

# ==================== 区域信号回调 ====================
func _on_area_connected(area: RenderArea) -> void:
	if not area is RenderAreaHand and not area is RenderAreaPlayers:
		return
	if not area.render_requested.is_connected(_on_area_render_event):
		area.render_requested.connect(_on_area_render_event)
	if not area.tween_requested.is_connected(_on_area_render_event):
		area.tween_requested.connect(_on_area_render_event)
	if area not in _connected_areas:
		_connected_areas.append(area)

func _on_area_render_event(event: RenderEvent) -> void:
	var type := event.get_type()
	if type == RenderEvent.DefaultType.INTO_AREA:
		_in_area = true
	elif type == RenderEvent.DefaultType.OUTTO_AREA:
		_in_area = false
		_remove_line_only()
		_hide_enemy_line()
	elif type == RenderEvent.DefaultType.CARD_START_DRAGGING:
		_is_dragging = true
		_remove_line_only()
		_hide_hand_arrow()
		_hide_enemy_line()
		_to_idle()
		return
	elif type == RenderEvent.DefaultType.CARD_CANCEL_DRAGGING:
		_is_dragging = false
	_schedule_evaluation()

# ==================== 评估调度 ====================
func _schedule_evaluation() -> void:
	if not is_inside_tree() or _is_dragging:
		return
	_evaluate_arrows()

func _evaluate_arrows() -> void:
	if not render_context or _is_dragging:
		return
	var hand_area: RenderArea = render_context.get_render_area(HAND_AREA_NAME)
	var players_area: RenderArea = render_context.get_render_area(PLAYERS_AREA_NAME)
	if not hand_area or not players_area:
		return
	_remove_line_only()
	_hide_enemy_line()
	_enemy_line_updated = false
	_activation_timestamp = Time.get_ticks_msec()
	_change_state(State.WAITING)

func _apply_arrow_evaluation() -> void:
	if not render_context:
		return
	var hand_area: RenderAreaHand = render_context.get_render_area(HAND_AREA_NAME)
	var players_area: RenderAreaPlayers = render_context.get_render_area(PLAYERS_AREA_NAME)
	if not hand_area or not players_area:
		return
	_apply_hand_arrow(hand_area.get_selected_items())
	_apply_player_arrow(players_area.get_selected_items(), players_area)

# ==================== 手牌箭头操控 ====================
func _apply_hand_arrow(hand_selected: Array[RenderItem]) -> void:
	if hand_selected.size() > 0:
		_point_hand_arrow_to(hand_selected[-1])
		return
	_hide_hand_arrow()

func _point_hand_arrow_to(card: RenderItem) -> void:
	var target_pos: Vector2 = ArrowNode.get_card_top_center_global(card)
	var dir: Vector2 = Vector2.DOWN
	if _cached_hand_target == target_pos and _cached_hand_dir == dir and _hand_arrow.state != ArrowNode.State.HIDDEN:
		return
	_hand_arrow.point_to_target(target_pos, dir)
	_cached_hand_target = target_pos
	_cached_hand_dir = dir
	_line_curve_valid = false

func _hide_hand_arrow() -> void:
	_hand_arrow.hide_arrow()
	_cached_hand_target = Vector2.INF
	_line_curve_valid = false

# ==================== 玩家箭头操控 ====================
func _apply_player_arrow(player_selected: Array[RenderItem], players_area: RenderArea) -> void:
	if player_selected.size() == 0:
		_hide_player_arrow()
		return
	var player: RenderItem = player_selected[-1]
	var target_item: RenderItem = _resolve_target(player)
	_target_player = player
	_target_item = target_item

	if not target_item:
		_hide_player_arrow()
		return
	var is_local: bool = false
	if players_area is RenderAreaPlayers:
		is_local = (player == (players_area as RenderAreaPlayers).local_player)
	_is_local_target = is_local
	var target_pos: Vector2
	var direction: Vector2
	if target_item == player:
		if is_local:
			target_pos = ArrowNode.get_card_top_center_global(player)
			direction = Vector2.DOWN
		else:
			target_pos = ArrowNode.get_card_bottom_center_global(player)
			direction = Vector2.UP
	else:
		target_pos = ArrowNode.get_card_bottom_center_global(target_item)
		direction = Vector2.UP
	if _cached_player_target == target_pos and _cached_player_dir == direction:
		return
	_player_arrow.point_to_target(target_pos, direction)
	_cached_player_target = target_pos
	_cached_player_dir = direction
	_line_curve_valid = false

func _hide_player_arrow() -> void:
	_player_arrow.hide_arrow()
	_cached_player_target = Vector2.INF
	_line_curve_valid = false
	_target_player = null
	_target_item = null

# ==================== 目标解析 ====================
func _resolve_target(player: RenderItem) -> RenderItem:
	if not render_context:
		return player
	var pid: int = 0
	if player.data:
		pid = player.data.get_id()
	if pid <= 0:
		return player
	var defence_area: RenderArea = render_context.get_render_area(DEFENCE_AREA_NAME, pid)
	if defence_area and not defence_area.items_pool.is_empty():
		var last_item: RenderItem = defence_area.items_pool[-1]
		if last_item:
			return last_item
	return player

# ==================== 状态机处理 ====================
func _change_state(new_state: State) -> void:
	_state = new_state
	if _state != State.IDLE:
		set_process(true)

func _to_idle() -> void:
	_state = State.IDLE
	_activation_timestamp = 0
	set_process(false)

func _waiting_process() -> void:
	if Time.get_ticks_msec() - _activation_timestamp < ACTIVATION_DELAY_MS:
		return
	_change_state(State.ARRANGING)

func _arranging_process() -> void:
	_apply_arrow_evaluation()
	_change_state(State.DRAWING)

func _drawing_process() -> void:
	if _hand_arrow.state != ArrowNode.State.STABLE or _player_arrow.state != ArrowNode.State.STABLE:
		return
	# 主线处理
	if not _line_curve_valid and _in_area:
		_build_line()
	if _in_area and _line_curve_valid and _line.state == ArrowLine.State.HIDDEN:
		_line.start_animation(self)
	if _line.state == ArrowLine.State.ANIMATING:
		_needs_redraw = true
	if _line.state == ArrowLine.State.STABLE:
		# 敌方线已在 _build_line 中启动，只需等待其动画完成
		if _enemy_line.state == ArrowLine.State.ANIMATING:
			_needs_redraw = true
		elif _enemy_line.state == ArrowLine.State.STABLE or _enemy_line.state == ArrowLine.State.HIDDEN:
			_to_idle()

# ==================== 主线连线管理 ====================
func _build_line() -> void:
	_line_curve_valid = true
	_line.kill_animation()
	var start: Vector2 = _hand_arrow.get_tail_global()
	var end: Vector2 = _player_arrow.get_tail_global()
	var start_tangent_up: bool = not _hand_arrow.direction.is_equal_approx(Vector2.UP)
	var end_tangent_up: bool = not _player_arrow.direction.is_equal_approx(Vector2.UP)
	var curve: Curve2D = MathUtils.create_smooth_curve(start, end, start_tangent_up, end_tangent_up)
	_line.points = curve.tessellate(CURVE_TESSELLATE_PRECISION)
	var offset: Vector2 = global_position
	for i: int in _line.points.size():
		_line.points[i] -= offset
	_line.start_animation(self)
	_needs_redraw = true

	# 同时构建守区非我方牌指示线（若条件满足）
	_build_enemy_line_if_possible()

# ==================== 守区非我方牌指示线（无箭头） ====================
func _build_enemy_line_if_possible() -> void:
	# 获取守区区域（当前玩家的守区）
	var player_id: int = _target_player.data.get_id() if _target_player and _target_player.data else 0
	if player_id <= 0:
		_hide_enemy_line()
		return
	var defence_area: RenderArea = render_context.get_render_area(DEFENCE_AREA_NAME, player_id)
	if not defence_area:
		_hide_enemy_line()
		return
	# 检查预览模式
	var preview_mode: Variant = defence_area.get_face_cache(&"nfn:preview_mode")
	if not preview_mode or preview_mode != true:
		_hide_enemy_line()
		return
	# 获取顶层和次层牌
	var pool: Array = defence_area.items_pool
	if pool.is_empty():
		_hide_enemy_line()
		return
	var top_card: RenderItem = pool[-1]
	var second_card: RenderItem = pool[-2] if pool.size() >= 2 else null
	var local_id: int = render_context.area_manager.local_player_id if render_context and render_context.area_manager else 0
	# 选择牌：顶层优先，若顶层非我方则用顶层，否则检查次层
	var selected_card: RenderItem = null
	var top_owner: int = (top_card.data as CardPack).player_id if top_card.data is CardPack else 0
	if top_owner != local_id and top_owner != 0:
		selected_card = top_card
	elif second_card:
		var second_owner: int = (second_card.data as CardPack).player_id if second_card.data is CardPack else 0
		if second_owner != local_id and second_owner != 0:
			selected_card = second_card
	if not selected_card:
		_hide_enemy_line()
		return
	# 获取牌的所有者玩家实体
	var owner_id: int = (selected_card.data as CardPack).player_id if selected_card.data is CardPack else 0
	if owner_id == 0:
		_hide_enemy_line()
		return
	var owner_player: RenderItem = _get_player_by_id(owner_id)
	if not owner_player:
		_hide_enemy_line()
		return

	# 构建曲线
	_enemy_line.kill_animation()
	var start: Vector2 = ArrowNode.get_card_top_center_global(selected_card)
	var end: Vector2 = ArrowNode.get_card_bottom_center_global(owner_player)
	var curve: Curve2D = MathUtils.create_smooth_curve(start, end, true, false)
	_enemy_line.points = curve.tessellate(CURVE_TESSELLATE_PRECISION)
	var offset: Vector2 = global_position
	for i: int in _enemy_line.points.size():
		_enemy_line.points[i] -= offset
	_enemy_line.start_animation(self)
	_enemy_line_updated = true
	_needs_redraw = true

func _get_player_by_id(player_id: int) -> RenderItem:
	if not render_context:
		return null
	var players_area: RenderArea = render_context.get_render_area(PLAYERS_AREA_NAME)
	if not players_area:
		return null
	for item in players_area.items_pool:
		if item.data and item.data.get_id() == player_id:
			return item
	return null

func _remove_line_only() -> void:
	_line.kill_animation()
	_needs_redraw = true

func _hide_enemy_line() -> void:
	if _enemy_line.state != ArrowLine.State.HIDDEN:
		_enemy_line.kill_animation()
		_needs_redraw = true
	_enemy_line_updated = false

# ==================== 绘制 ====================
func _draw() -> void:
	# 主线
	if _in_area and _line.state != ArrowLine.State.HIDDEN and not _line.points.is_empty():
		if _line.outer_width > 0.0 and _line.outer_color.a > 0.0:
			draw_polyline(_line.points, _line.outer_color, _line.outer_width, true)
		if _line.inner_alpha > 0.0:
			var col: Color = _line.inner_color
			col.a = _line.inner_alpha
			draw_polyline(_line.points, col, _line.inner_width, true)
	# 守区非我方牌指示线
	if _in_area and _enemy_line.state != ArrowLine.State.HIDDEN and not _enemy_line.points.is_empty():
		if _enemy_line.outer_width > 0.0 and _enemy_line.outer_color.a > 0.0:
			draw_polyline(_enemy_line.points, _enemy_line.outer_color, _enemy_line.outer_width, true)
		if _enemy_line.inner_alpha > 0.0:
			var col: Color = _enemy_line.inner_color
			col.a = _enemy_line.inner_alpha
			draw_polyline(_enemy_line.points, col, _enemy_line.inner_width, true)

# ==================== 清理 ====================
func _stop_render() -> void:
	_line.kill_animation()
	_line.points.clear()
	_enemy_line.kill_animation()
	_enemy_line.points.clear()
	_hand_arrow.hide_arrow()
	_player_arrow.hide_arrow()
	_line_curve_valid = false
	_activation_timestamp = 0
	_needs_redraw = false
	_cached_hand_target = Vector2.INF
	_cached_player_target = Vector2.INF
	_target_player = null
	_target_item = null
	_enemy_line_updated = false
	_state = State.IDLE

func _cleanup_all() -> void:
	_stop_render()
