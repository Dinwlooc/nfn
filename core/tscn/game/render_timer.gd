## 计时器显示：环形进度条显示剩余时间占比，环内写以秒为单位的整数倒计时。
## 计时器每次更新时，环用 0.5s 缓动从当前占比滑到新的起点，避免直接跳变。
## 环色只由剩余秒数决定：60 秒及以上固定为绿，60 秒到 0 秒按剩余占比由绿插值到红。
## 控件随鼠标做层视差，随动幅度用同一条剩余占比插值收缩，越接近 0 越沉。
extends Control

#==consts==
## 全局注册表中的计时器类型键
const TIMER_TYPE: StringName = &"timer"
## 进度环半径（像素）
const RING_RADIUS: float = 44.0
## 进度环线宽（像素）
const RING_WIDTH: float = 7.0
## 环底轨道颜色
const TRACK_COLOR: Color = Color(1.0, 1.0, 1.0, 0.15)
## 颜色映射起点：剩余秒数达到或超过该值固定为绿
const COLOR_RAMP_SECONDS: float = 60.0
## 环心数值字号
const VALUE_FONT_SIZE: int = 26
## 圆弧细分点数
const ARC_POINT_COUNT: int = 64
## 计时更新时填充环的缓动时长（秒）
const FILL_EASE_DURATION: float = 0.5
## 判定计时更新的最小回跳量（秒）
const RESET_JUMP_EPSILON: float = 0.05
## 层视差换算工具
const LayerParallax = preload("res://core/Class/Face/Utils/LayerParallax.gd")
## 视差深度系数
const PARALLAX_DEPTH: float = 0.60
## 推离幅度（屏幕像素）
const PARALLAX_PUSH: float = 30.0
## 推离的深度混入量
const PARALLAX_PUSH_MIX: float = 0.15
## 吸向幅度（屏幕像素）
const PARALLAX_PULL: float = 3.0
## 吸向的深度指数
const PARALLAX_PULL_POWER: float = 2.5
## 指针死区
const PARALLAX_DEADZONE: float = 0.08
## 跟随平滑（每秒衰减率）
const PARALLAX_FOLLOW: float = 10.0
## 远离缩小的影响半径（屏幕像素），与角色属性表现一致
const PARALLAX_RADIUS: float = 420.0
## 半径处的缩放下限，与角色属性表现一致
const PARALLAX_MIN_SCALE: float = 0.92

#==nodes==
## 环心数值标签
var value_label: Label = null

#==vars==
## 缓存计时器实例
var _timer: GameTimer = null
## 上次显示的整数值（用于避免不必要的更新）
var _last_displayed_value: int = -1
## 当前绘制的占比：缓动期间与真实占比不同
var _display_ratio: float = 0.0
## 上次读到的剩余秒数（用于判定计时更新）
var _last_time_left: float = 0.0
## 本次缓动的起点占比
var _fill_from: float = 0.0
## 本次缓动已进行的时长（秒），初值等于时长表示不在缓动
var _fill_elapsed: float = FILL_EASE_DURATION
## 控件基准位置：视差围绕它偏移
var _base_position: Vector2 = Vector2.ZERO
## 平滑后的视差位移
var _parallax_offset: Vector2 = Vector2.ZERO
## 平滑后的随动缩放
var _parallax_scale: float = 1.0

#==lifecycle==
## 就绪：记录基准位置、建数值标签并订阅计时器注册
## @signal_listener
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base_position = position
	_setup_value_label()
	GlobalRegistry.connect_singleton(TIMER_TYPE, _on_timer_registered)

## 每物理帧：判计时更新、推缓动与视差、刷新文本并重绘
## @override
func _physics_process(delta: float) -> void:
	if not _timer:
		return
	var time_left: float = _timer.time_left
	if time_left > _last_time_left + RESET_JUMP_EPSILON:
		_fill_from = _display_ratio
		_fill_elapsed = 0.0
	_last_time_left = time_left
	_update_fill(delta, time_left)
	_refresh_value_label(time_left)
	_update_parallax(delta, time_left)
	queue_redraw()

#==draw==
## 绘制环底轨道与按当前占比顺时针扫出的进度弧
## @override
func _draw() -> void:
	if not _timer:
		return
	var center := size * 0.5
	draw_arc(center, RING_RADIUS, 0.0, TAU, ARC_POINT_COUNT, TRACK_COLOR, RING_WIDTH, true)
	if _display_ratio <= 0.0:
		return
	draw_arc(center, RING_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * _display_ratio, ARC_POINT_COUNT, Color.from_hsv(_ramp(_timer.time_left) / 3.0, 1.0, 1.0), RING_WIDTH, true)

#==hooks==
## 计时器注册回调：只接受 GameTimer 实例
## @signal_listener
func _on_timer_registered(instance: Node) -> void:
	if instance is GameTimer:
		_timer = instance

#==internal==
## 剩余占比：time_left 相对本次计时起点，夹在 0 到 1
## @pure
func _real_ratio(time_left: float) -> float:
	var start_time: float = _timer.wait_time
	if start_time <= 0.0:
		return 0.0
	return clampf(time_left / start_time, 0.0, 1.0)

## 剩余秒数到 0 至 1 的映射：60 秒及以上为 1，供颜色与视差幅度共用
## @pure
func _ramp(time_left: float) -> float:
	return clampf(time_left / COLOR_RAMP_SECONDS, 0.0, 1.0)

## 推进填充缓动：从本次缓动起点滑向实时占比，缓动结束后直接取实时占比
## @side_effect
func _update_fill(delta: float, time_left: float) -> void:
	var real_ratio: float = _real_ratio(time_left)
	if _fill_elapsed >= FILL_EASE_DURATION:
		_display_ratio = real_ratio
		return
	_fill_elapsed += delta
	var progress: float = clampf(_fill_elapsed / FILL_EASE_DURATION, 0.0, 1.0)
	_display_ratio = lerpf(_fill_from, real_ratio, 1.0 - pow(1.0 - progress, 3.0))

## 按指针更新视差位移与远离缩小，幅度乘上剩余占比：越接近 0 位移越小、缩得越轻
## @side_effect
func _update_parallax(delta: float, time_left: float) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var pointer: Vector2 = LayerParallax.normalize_pointer(mouse_position, viewport_size, PARALLAX_DEADZONE)
	var parent_item: CanvasItem = get_parent() as CanvasItem
	var base_center: Vector2 = _base_position + size * 0.5
	var center_global: Vector2 = parent_item.get_global_transform() * base_center if parent_item else base_center
	var push: Vector2 = LayerParallax.push_vector(pointer, PARALLAX_DEPTH, PARALLAX_PUSH, PARALLAX_PUSH_MIX)
	var pull: Vector2 = LayerParallax.pull_vector(center_global, mouse_position, PARALLAX_DEPTH, PARALLAX_PULL, PARALLAX_PULL_POWER)
	var target_offset: Vector2 = LayerParallax.offset_for(push + pull, 1.0) * _ramp(time_left)
	_parallax_offset = _parallax_offset.lerp(target_offset, 1.0 - exp(-PARALLAX_FOLLOW * delta))
	var target_scale: float = LayerParallax.scale_for(center_global, mouse_position, PARALLAX_RADIUS, PARALLAX_MIN_SCALE)
	_parallax_scale = lerpf(_parallax_scale, target_scale, 1.0 - exp(-PARALLAX_FOLLOW * delta))
	pivot_offset = size * 0.5
	scale = Vector2(_parallax_scale, _parallax_scale)
	position = _base_position + _parallax_offset

## 刷新环心数值：整秒变化时才写文本，单位固定为 s
## @side_effect
func _refresh_value_label(time_left: float) -> void:
	var current_value: int = ceili(time_left)
	if current_value == _last_displayed_value:
		return
	_last_displayed_value = current_value
	value_label.text = "%ds" % current_value

## 建环心数值标签：居中、字号固定、忽略鼠标并铺满控件
## @side_effect
func _setup_value_label() -> void:
	value_label = Label.new()
	value_label.name = &"Value"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override(&"font_size", VALUE_FONT_SIZE)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(value_label)
	value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
