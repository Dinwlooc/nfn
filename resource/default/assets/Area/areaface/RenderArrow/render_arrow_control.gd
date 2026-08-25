## 动态箭头管理器：维护手牌箭头、玩家箭头、连接线，以及守区非我方牌到其所有者的指示线。
## 通过信号驱动更新，主循环使用状态机（等待→排列→绘制）轮询。
extends Control

# 导入内部依赖
const ArrowNode = preload("arrow_node.gd")
const ArrowLine = preload("arrow_line.gd")
const ArrowLineBuilder = preload("arrow_line_builder.gd")
const ArrowEvaluator = preload("arrow_evaluator.gd")

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
## 标记敌方曲线是否已经更新（防止重复构建）
var _enemy_line_updated: bool = false

var render_context: RenderContext
@export var render_control: RenderControl
## 当前状态
var _state: State = State.IDLE

## 子组件实例
var _line_builder: ArrowLineBuilder
var _evaluator: ArrowEvaluator

# ==================== 生命周期 ====================
func _ready() -> void:
	if not render_control:
		return
	render_context = render_control.render_context
	if not render_context:
		return
	_line_builder = ArrowLineBuilder.new()
	_evaluator = ArrowEvaluator.new()
	_hand_arrow = ArrowNode.new()
	_player_arrow = ArrowNode.new()
	_line = ArrowLine.new()
	_enemy_line = ArrowLine.new()
	add_child(_hand_arrow)
	add_child(_player_arrow)
	_hand_arrow.hide_arrow()
	_player_arrow.hide_arrow()
	_enemy_line.kill_animation()
	_evaluator.init(_hand_arrow, _player_arrow, render_context)
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

func _apply_arrow_evaluation() -> void:
	if not render_context:
		return
	var hand_area: RenderAreaHand = render_context.get_render_area(HAND_AREA_NAME)
	var players_area: RenderAreaPlayers = render_context.get_render_area(PLAYERS_AREA_NAME)
	if not hand_area or not players_area:
		return
	var hand_changed := _evaluator.apply_hand_arrow(hand_area.get_selected_items())
	var player_changed := _evaluator.apply_player_arrow(players_area.get_selected_items(), players_area)
	if hand_changed or player_changed:
		_line_curve_valid = false  # 箭头移动，强制重建线

func _drawing_process() -> void:
	if _hand_arrow.state != ArrowNode.State.STABLE or _player_arrow.state != ArrowNode.State.STABLE:
		return
	if not _line_curve_valid and _in_area:
		_build_line()
	if _in_area and _line_curve_valid and _line.state == ArrowLine.State.HIDDEN:
		_line.start_animation(self)
	if _line.state == ArrowLine.State.ANIMATING:
		_needs_redraw = true
	if _line.state == ArrowLine.State.STABLE:
		if _enemy_line.state == ArrowLine.State.ANIMATING:
			_needs_redraw = true
		elif _enemy_line.state == ArrowLine.State.STABLE or _enemy_line.state == ArrowLine.State.HIDDEN:
			_to_idle()

# ==================== 主线连线管理（委托给构建器） ====================
func _build_line() -> void:
	_line_curve_valid = true
	var success := _line_builder.build_main_line(
		_hand_arrow,
		_player_arrow,
		_line,
		self,
		global_position
	)
	if success:
		_needs_redraw = true
	_build_enemy_line()

func _build_enemy_line() -> void:
	var target_player := _evaluator.target_player
	var success := _line_builder.build_enemy_line(
		target_player,
		render_context,
		_enemy_line,
		self,
		global_position
	)
	if success:
		_enemy_line_updated = true
		_needs_redraw = true
	else:
		_hide_enemy_line()

# ==================== 隐藏辅助 ====================
func _remove_line_only() -> void:
	_line.kill_animation()
	_needs_redraw = true

func _hide_enemy_line() -> void:
	if _enemy_line.state != ArrowLine.State.HIDDEN:
		_enemy_line.kill_animation()
		_needs_redraw = true
	_enemy_line_updated = false

func _hide_hand_arrow() -> void:
	_hand_arrow.hide_arrow()
	_evaluator.clear_cache()

# ==================== 绘制 ====================
func _draw() -> void:
	if _in_area and _line.state != ArrowLine.State.HIDDEN and not _line.points.is_empty():
		if _line.outer_width > 0.0 and _line.outer_color.a > 0.0:
			draw_polyline(_line.points, _line.outer_color, _line.outer_width, true)
		if _line.inner_alpha > 0.0:
			var col: Color = _line.inner_color
			col.a = _line.inner_alpha
			draw_polyline(_line.points, col, _line.inner_width, true)
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
	_enemy_line_updated = false
	_state = State.IDLE

func _cleanup_all() -> void:
	_stop_render()
