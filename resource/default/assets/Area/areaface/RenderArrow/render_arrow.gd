## 动态箭头管理器：维护手牌箭头、玩家箭头和连接线。
## 通过信号驱动更新，主循环使用状态机（等待→排列→绘制）轮询。
extends Control
class_name RenderArrow

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
## 连接线
var _line: ArrowLine
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
	add_child(_hand_arrow)
	add_child(_player_arrow)
	_hand_arrow.hide_arrow()
	_player_arrow.hide_arrow()
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
	# 任何非 IDLE 状态都可能需要重绘
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
	elif type == RenderEvent.DefaultType.CARD_START_DRAGGING:
		_is_dragging = true
		_remove_line_only()
		_hide_hand_arrow()
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
	# 开始新的评估：清理线，记录时间戳，进入 WAITING 状态
	_remove_line_only()
	_activation_timestamp = Time.get_ticks_msec()
	_change_state(State.WAITING)

## 实际应用箭头指向（检查缓存，跳过未变化的指向）
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

## 根据手牌选中项更新手牌箭头
func _apply_hand_arrow(hand_selected: Array[RenderItem]) -> void:
	if hand_selected.size() > 0:
		_point_hand_arrow_to(hand_selected[-1])
		return
	_hide_hand_arrow()

## 使手牌箭头指向指定卡片（若缓存匹配则跳过）
func _point_hand_arrow_to(card: RenderItem) -> void:
	var target_pos: Vector2 = ArrowNode.get_card_top_center_global(card)
	var dir: Vector2 = Vector2.DOWN
	if _cached_hand_target == target_pos and _cached_hand_dir == dir and _hand_arrow.state != ArrowNode.State.HIDDEN:
		return
	_hand_arrow.point_to_target(target_pos, dir)
	_cached_hand_target = target_pos
	_cached_hand_dir = dir
	_line_curve_valid = false

## 隐藏手牌箭头并清空缓存，同时标记曲线失效
func _hide_hand_arrow() -> void:
	_hand_arrow.hide_arrow()
	_cached_hand_target = Vector2.INF
	_line_curve_valid = false

# ==================== 玩家箭头操控 ====================

## 根据玩家选中项更新玩家箭头（需解析实际目标）
func _apply_player_arrow(player_selected: Array[RenderItem], players_area: RenderArea) -> void:
	if player_selected.size() == 0:
		_hide_player_arrow()
		return
	var player: RenderItem = player_selected[-1]
	var target_item: RenderItem = _resolve_target(player)
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

## 隐藏玩家箭头并清空缓存，同时标记曲线失效
func _hide_player_arrow() -> void:
	_player_arrow.hide_arrow()
	_cached_player_target = Vector2.INF
	_line_curve_valid = false

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

## 切换到指定状态，并确保 process 开启（非 IDLE 时）
func _change_state(new_state: State) -> void:
	_state = new_state
	if _state != State.IDLE:
		set_process(true)

## 转为空闲状态并关闭主循环
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
	# 区域内且曲线失效时构建新曲线并播放
	if not _line_curve_valid and _in_area:
		_build_line()
	# 区域内曲线有效且线隐藏/稳定（未在动画中）时，启动动画
	if _in_area and _line_curve_valid and _line.state == ArrowLine.State.HIDDEN:
		_line.start_animation(self)
	# 线动画进行中需要持续重绘
	if _line.state == ArrowLine.State.ANIMATING:
		_needs_redraw = true
	# 两箭头稳定且线已进入稳定状态，结束本轮绘制
	if _line.state == ArrowLine.State.STABLE:
		_to_idle()
# ==================== 连线管理 ====================
func _build_line() -> void:
	_line_curve_valid = true
	_line.kill_animation()
	var start: Vector2 = _hand_arrow.get_tail_global()
	var end: Vector2 = _player_arrow.get_tail_global()
	# 曲线从箭尾延伸，切线方向与箭头方向相反
	var start_tangent_up: bool = not _hand_arrow.direction.is_equal_approx(Vector2.UP)
	var end_tangent_up: bool = not _player_arrow.direction.is_equal_approx(Vector2.UP)
	var curve: Curve2D = ArrowLine.create_smooth_curve(start, end, start_tangent_up, end_tangent_up)
	_line.points = curve.tessellate(CURVE_TESSELLATE_PRECISION)
	var offset: Vector2 = global_position
	for i: int in _line.points.size():
		_line.points[i] -= offset
	_line.start_animation(self)
	_needs_redraw = true
## 仅停止线动画并请求重绘（保留曲线点集）
func _remove_line_only() -> void:
	_line.kill_animation()
	_needs_redraw = true

## 完全停止所有渲染并清除数据（退出树时使用）
func _stop_render() -> void:
	_line.kill_animation()
	_line.points.clear()
	_hand_arrow.hide_arrow()
	_player_arrow.hide_arrow()
	_line_curve_valid = false
	_activation_timestamp = 0
	_needs_redraw = false
	_cached_hand_target = Vector2.INF
	_cached_player_target = Vector2.INF
	_state = State.IDLE

# ==================== 绘制 ====================
func _draw() -> void:
	# 不在区域内或线处于隐藏状态时不绘制
	if not _in_area or _line.state == ArrowLine.State.HIDDEN or _line.points.is_empty():
		return
	if _line.outer_width > 0.0 and _line.outer_color.a > 0.0:
		draw_polyline(_line.points, _line.outer_color, _line.outer_width, true)
	if _line.inner_alpha > 0.0:
		var col: Color = _line.inner_color
		col.a = _line.inner_alpha
		draw_polyline(_line.points, col, _line.inner_width, true)

# ==================== 清理 ====================
func _cleanup_all() -> void:
	_stop_render()
