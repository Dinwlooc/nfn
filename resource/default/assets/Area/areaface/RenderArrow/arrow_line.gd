## 闪电连接线的数据与动画类，负责存储曲线点集、执行电光闪烁动画。
extends RefCounted
class_name ArrowLine

## 曲线局部坐标点集
var points: PackedVector2Array = PackedVector2Array()
## 内线颜色
var inner_color: Color = Color.AQUA
## 外线起始颜色
var outer_start_color: Color = Color.WHITE
## 外线起始宽度
var outer_start_width: float = 8.0
## 外线结束宽度
var outer_end_width: float = 2.0
## 内线宽度
var inner_width: float = 2.0
## 外线动画时长
var outer_anim_time: float = 0.5
## 内线淡入时长
var inner_fadein_time: float = 0.1

## 当前外线颜色
var outer_color: Color = Color.WHITE
## 当前外线宽度
var outer_width: float = 8.0
## 当前内线透明度
var inner_alpha: float = 0.0

enum State { HIDDEN, ANIMATING, STABLE }
## 当前线状态
var state: State = State.HIDDEN

var _tween: Tween = null

## 启动电光闪烁动画，host 用于创建 Tween
func start_animation(host: Control) -> void:
	if state == State.ANIMATING:
		return
	outer_color = outer_start_color
	outer_width = outer_start_width
	inner_alpha = 0.0
	kill_tween()
	_tween = host.create_tween()
	state = State.ANIMATING
	_tween.set_parallel(true)
	_tween.tween_method(_set_outer_properties, 0.0, 1.0, outer_anim_time).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_inner_alpha, 0.0, 1.0, inner_fadein_time).set_ease(Tween.EASE_IN)
	_tween.chain()
	_tween.tween_callback(_on_animation_finished)

## 停止动画并重置为隐藏状态，同时清除视觉属性
func kill_animation() -> void:
	kill_tween()
	state = State.HIDDEN
	outer_color.a = 0.0
	inner_alpha = 0.0

func kill_tween() -> void:
	if _tween:
		_tween.kill()
		_tween = null

func _set_outer_properties(progress: float) -> void:
	outer_color = outer_start_color.lerp(inner_color, progress)
	outer_width = lerpf(outer_start_width, outer_end_width, progress)

func _set_inner_alpha(alpha: float) -> void:
	inner_alpha = alpha

func _on_animation_finished() -> void:
	state = State.STABLE
	outer_color = inner_color
	outer_width = outer_end_width
	inner_alpha = 1.0
	_tween = null

# ==================== 纯函数 ====================

## 生成连接两点的平滑曲线。
## [param start_tangent_up]: true 表示起点处切线向上，false 表示切线向下。
## [param end_tangent_up]: true 表示终点处切线向上，false 表示切线向下。
static func create_smooth_curve(start: Vector2, end: Vector2, start_tangent_up: bool, end_tangent_up: bool) -> Curve2D:
	const TANGENT_FACTOR: float = 200.0
	const MIN_TANGENT_LENGTH: float = 100.0
	const MAX_TANGENT_LENGTH: float = 400.0
	var horizontal_dist: float = abs(start.x - end.x)
	var vertical_dist: float = abs(start.y - end.y)
	var offset_multiplier: float = clamp(TANGENT_FACTOR / max(horizontal_dist, 1.0), 1.0, 1.5)
	var base_offset: float = vertical_dist * 0.5 * offset_multiplier
	var is_same_direction: bool = (start_tangent_up == end_tangent_up)
	var start_out: Vector2
	var end_in: Vector2
	if is_same_direction:
		# 切线向上时 sign=-1，向下时 sign=1
		var sign: float = -1.0 if start_tangent_up else 1.0
		var dy: float = end.y - start.y
		var abs_dy: float = abs(dy)
		var min_dist: float
		if abs_dy == 0.0:
			min_dist = max(base_offset, MIN_TANGENT_LENGTH)
		else:
			var factor: float = 50.0
			min_dist = factor * (horizontal_dist / abs_dy)
			min_dist = clamp(min_dist, 0.0, MAX_TANGENT_LENGTH)
		var d_s: float
		var d_e: float
		if sign * dy > 0.0:
			d_e = min_dist
			d_s = d_e + abs_dy
		else:
			d_s = min_dist
			d_e = d_s + abs_dy
		start_out = Vector2(0.0, sign * d_s)
		end_in = Vector2(0.0, sign * d_e)
	else:
		var vertical_offset: float = base_offset
		start_out = Vector2(0.0, -vertical_offset) if start_tangent_up else Vector2(0.0, vertical_offset)
		end_in = Vector2(0.0, -vertical_offset) if end_tangent_up else Vector2(0.0, vertical_offset)
	var curve := Curve2D.new()
	curve.add_point(start, Vector2.ZERO, start_out)
	curve.add_point(end, end_in, Vector2.ZERO)
	return curve
