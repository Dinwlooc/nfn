extends Control
class_name CurveArrowManager

# 曲线属性
const COLOR_1 = Color(Color.AQUA, 0)
const COLOR_2 = Color.AQUA
const TWEEN_TIME = 1.0
const ARROW_WIDTH_FACTOR = 4.0
const ARROW_HEIGHT_FACTOR = 5.0

var curve_color: Color = COLOR_1
var curve_width: float = 10.0
var precision: int = 5
var points: PackedVector2Array
var has_valid_points: bool
var tween: Tween
var arrow_points: PackedVector2Array

# 创建平滑曲线（根据起点和终点是否为顶部确定切线方向）
func create_smooth_curve(start: Vector2, end: Vector2, start_is_top: bool, end_is_top: bool) -> Curve2D:
	var curve = Curve2D.new()
	var horizontal_dist:float = abs(start.x - end.x)
	var vertical_dist:float = abs(start.y - end.y)
	var offset_multiplier:float = clamp(200.0 / max(horizontal_dist, 1.0), 1.0, 1.5)
	var base_offset:float = vertical_dist * 0.5 * offset_multiplier
	var min_offset:float = 400.0
	var is_same_direction: bool = (start_is_top == end_is_top)
	var start_out: Vector2
	var end_in: Vector2
	if is_same_direction:
		var sign: float = -1.0 if start_is_top else 1.0  # 起点出切线方向（向上为负，向下为正）
		var dy: float = end.y - start.y
		var abs_dy: float = abs(dy)
		var min_dist: float
		if abs_dy == 0:
			min_dist = max(base_offset, min_offset)
		else:
			var factor: float = 50.0  # 比例常数，可调整
			min_dist = factor * (horizontal_dist / abs_dy)
			min_dist = clamp(min_dist, 0, 400.0)  # 限制范围避免极端
		var d_s: float
		var d_e: float
		if sign * dy > 0:
			d_e = min_dist
			d_s = d_e + abs_dy
		else:
			d_s = min_dist
			d_e = d_s + abs_dy
		start_out = Vector2(0, sign * d_s)
		end_in = Vector2(0, sign * d_e)
	else:
		var vertical_offset: float = base_offset
		start_out = Vector2(0, -vertical_offset) if start_is_top else Vector2(0, vertical_offset)
		end_in = Vector2(0, -vertical_offset) if end_is_top else Vector2(0, vertical_offset)
	curve.add_point(start, Vector2.ZERO, start_out)
	curve.add_point(end, end_in, Vector2.ZERO)
	return curve
	curve.add_point(start, Vector2.ZERO, start_out)
	curve.add_point(end, end_in, Vector2.ZERO)
	return curve

# 计算箭头三角形点（arrow_up = true 表示箭头尖端向上）
func calculate_arrow_points(end_point: Vector2, arrow_up: bool) -> PackedVector2Array:
	var arrow_height:float = curve_width * ARROW_HEIGHT_FACTOR
	var arrow_width:float = curve_width * ARROW_WIDTH_FACTOR
	if arrow_up:
		return [
			end_point + Vector2(-arrow_width/2, 0),  # 左下（底边左）
			end_point + Vector2(arrow_width/2, 0),   # 右下（底边右）
			end_point + Vector2(0, -arrow_height)    # 顶点（向上）
		]
	else:
		return [
			end_point + Vector2(-arrow_width/2, 0),  # 左上（底边左）
			end_point + Vector2(arrow_width/2, 0),   # 右上（底边右）
			end_point + Vector2(0, arrow_height)     # 顶点（向下）
		]

# 绘制曲线（end_is_top = true 表示终点在顶部，false 表示在底部）
func draw_curve(start: Vector2, target: Vector2, end_is_top: bool) -> void:
	# 计算曲线终点偏移：顶部目标向上偏移（负y），底部目标向下偏移（正y）
	var direction: int = -1 if end_is_top else 1
	var offset: float = direction * curve_width * ARROW_HEIGHT_FACTOR
	var curve_end: Vector2 = target + Vector2(0, offset)
	var curve: Curve2D = create_smooth_curve(start, curve_end, true, end_is_top)
	points = curve.tessellate(precision)
	has_valid_points = points.size() >= 2
	if has_valid_points:
		var arrow_up: bool = not end_is_top
		arrow_points = calculate_arrow_points(points[-1], arrow_up)
	else:
		arrow_points = PackedVector2Array()
	tween = create_tween().set_loops()
	tween.tween_method(draw_tween, COLOR_1, COLOR_2, 0.5)
	tween.tween_method(draw_tween, COLOR_2, COLOR_1, 0.5)

func _draw() -> void:
	if has_valid_points:
		if arrow_points.size() == 3:
			draw_colored_polygon(arrow_points, curve_color)
		draw_polyline(points, curve_color, curve_width, true)

func clear_arrow() -> void:
	visible = false
	if tween:
		tween.kill()

func draw_tween(color):
	curve_color = color
	queue_redraw()
