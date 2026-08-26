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
## 是否正在拖拽卡牌
var _is_dragging: bool = false
## 当前是否处于“连线区域”（影响线的绘制与生成）
var _in_area: bool = false
## 是否需要重绘
var _needs_redraw: bool = false
## 标记敌方曲线是否已经更新（防止重复构建）
var _enemy_line_updated: bool = false
## 渲染上下文
var render_context: RenderContext
## 渲染控件引用
@export var render_control: RenderControl
## 当前状态
var _state: State = State.IDLE
## 子组件实例
var _line_builder: ArrowLineBuilder
var _evaluator: ArrowEvaluator
# ==================== 生命周期 ====================
## 初始化，创建子控件并连接区域信号
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
## 主循环处理状态机
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
## 退出场景时断开所有信号连接并清理
func _exit_tree() -> void:
	_cleanup_all()
	if not render_context:
		return
	render_context.disconnect_renderarea(HAND_AREA_NAME, _on_area_connected)
	render_context.disconnect_renderarea(PLAYERS_AREA_NAME, _on_area_connected)
# ==================== 区域信号回调 ====================
## 区域连接/替换回调（新架构），自动断开旧区域并连接新区域
func _on_area_connected(new_area: RenderArea, old_area: RenderArea) -> void:
	if old_area:
		if old_area.render_requested.is_connected(_on_area_render_event):
			old_area.render_requested.disconnect(_on_area_render_event)
		if old_area.tween_requested.is_connected(_on_area_render_event):
			old_area.tween_requested.disconnect(_on_area_render_event)
	if not new_area:
		return
	if not (new_area is RenderAreaHand) and not (new_area is RenderAreaPlayers):
		return
	new_area.render_requested.connect(_on_area_render_event)
	new_area.tween_requested.connect(_on_area_render_event)
## 区域事件回调，根据类型更新状态并触发评估
func _on_area_render_event(event: RenderEvent) -> void:
	match event.get_type():
		RenderEvent.DefaultType.INTO_AREA:
			_in_area = true
		RenderEvent.DefaultType.OUTTO_AREA:
			_in_area = false
			_remove_line_only()
			_hide_enemy_line()
		RenderEvent.DefaultType.CARD_START_DRAGGING:
			_is_dragging = true
			_remove_line_only()
			_hide_hand_arrow()
			_hide_enemy_line()
			_to_idle()
			return
		RenderEvent.DefaultType.CARD_CANCEL_DRAGGING:
			_is_dragging = false
		_:
			pass
	_schedule_evaluation()
# ==================== 评估调度 ====================
## 调度评估（非拖拽且树内时执行）
func _schedule_evaluation() -> void:
	if not is_inside_tree() or _is_dragging:
		return
	_evaluate_arrows()
## 执行箭头评估，重置敌方线状态并进入等待
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
## 切换状态并启用处理
func _change_state(new_state: State) -> void:
	_state = new_state
	if _state != State.IDLE:
		set_process(true)
## 回到空闲状态，停止处理
func _to_idle() -> void:
	_state = State.IDLE
	_activation_timestamp = 0
	set_process(false)
## 等待延迟结束
func _waiting_process() -> void:
	if Time.get_ticks_msec() - _activation_timestamp < ACTIVATION_DELAY_MS:
		return
	_change_state(State.ARRANGING)
## 执行箭头评估
func _arranging_process() -> void:
	_apply_arrow_evaluation()
	_change_state(State.DRAWING)
## 应用箭头评估结果，并标记曲线是否失效
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
		_line_curve_valid = false
## 绘制阶段：等待箭头稳定后构建或启动线动画
func _drawing_process() -> void:
	# 若已离开连线区域，直接退出
	if not _in_area:
		_to_idle()
		return
	# 等待箭头稳定
	if _hand_arrow.state != ArrowNode.State.STABLE or _player_arrow.state != ArrowNode.State.STABLE:
		return
	# 若曲线无效则尝试构建
	if not _line_curve_valid and not _build_line():
		_to_idle()
		return
	# 根据主线状态进行分支处理
	match _line.state:
		ArrowLine.State.HIDDEN:
			# 曲线已构建但未启动，启动动画
			_line.start_animation(self)
			_needs_redraw = true
		ArrowLine.State.ANIMATING:
			_needs_redraw = true
		ArrowLine.State.STABLE:
			# 主线稳定，处理敌方线
			if _enemy_line.state == ArrowLine.State.ANIMATING:
				_needs_redraw = true
				return
			# 敌方线已稳定或隐藏，完成绘制
			_to_idle()
		_:
			# 意外状态，安全退出
			_to_idle()
# ==================== 主线连线管理（委托给构建器） ====================
## 构建主线并触发敌方线构建，返回是否成功
func _build_line() -> bool:
	var success := _line_builder.build_main_line(
		_hand_arrow,
		_player_arrow,
		_line,
		self,
		global_position
	)
	if success:
		_line_curve_valid = true
		_needs_redraw = true
		_build_enemy_line()
		return true
	_line_curve_valid = false
	_hide_enemy_line()
	return false
## 构建敌方指示线（守区非我方牌指向其所有者）
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
		return
	_hide_enemy_line()
# ==================== 隐藏辅助 ====================
## 仅移除主线，不处理敌方线
func _remove_line_only() -> void:
	_line.kill_animation()
	_needs_redraw = true
## 隐藏敌方线，标记未更新
func _hide_enemy_line() -> void:
	if _enemy_line.state != ArrowLine.State.HIDDEN:
		_enemy_line.kill_animation()
		_needs_redraw = true
	_enemy_line_updated = false
## 隐藏手牌箭头并清空评估器缓存
func _hide_hand_arrow() -> void:
	_hand_arrow.hide_arrow()
	_evaluator.clear_cache()
# ==================== 绘制 ====================
## 绘制主线和敌方线（使用电光效果）
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
## 停止所有渲染，重置状态
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
## 完整清理，包括状态机停止
func _cleanup_all() -> void:
	_stop_render()
