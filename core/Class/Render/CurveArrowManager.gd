extends Control
class_name CurveArrowManager

# 曲线属性
const COLOR_1 = Color(Color.AQUA,0) 
const COLOR_2 = Color.AQUA
const TWEEN_TIME = 1.0
const ARROW_WIDTH_FACTOR = 4.0
const ARROW_HEIGHT_FACTOR = 5.0
var curve_color: Color = COLOR_1  # 曲线颜色
var curve_width: float = 10.0                   # 曲线宽度
var precision: int = 5   # 基础精度
var points:PackedVector2Array
var has_valid_points:bool
var tween:Tween
var arrow_points: PackedVector2Array

# 创建平滑曲线
func create_smooth_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve = Curve2D.new()
	if start.y < end.y:
		var temp = start
		start = end
		end = temp
	end.y += curve_width * ARROW_HEIGHT_FACTOR
	var horizontal_dist = abs(start.x - end.x)
	var vertical_dist = abs(start.y - end.y)
	var offset_multiplier = clamp(200.0 / max(horizontal_dist, 1.0), 1.0, 1.5)
	var vertical_offset = vertical_dist * 0.5 * offset_multiplier
	curve.add_point(start, Vector2.ZERO, Vector2(0, -vertical_offset))
	curve.add_point(end, Vector2(0, vertical_offset), Vector2.ZERO)   
	return curve

func calculate_arrow_points(end_point: Vector2) -> PackedVector2Array:
	var arrow_height = curve_width * ARROW_HEIGHT_FACTOR  
	var arrow_width = curve_width * ARROW_WIDTH_FACTOR   
	return [
		end_point + Vector2(-arrow_width/2, 0),  # 左下角
		end_point + Vector2(arrow_width/2, 0),   # 右下角
		end_point + Vector2(0, -arrow_height)        # 顶点（向上延伸）
	]
# 绘制曲线
func draw_curve(start: Vector2, end: Vector2) -> void:
	var curve = create_smooth_curve(start, end)
	points = curve.tessellate(precision)
	has_valid_points = points.size() >= 2
	if has_valid_points:
		arrow_points = calculate_arrow_points(points[-1])
	else:
		arrow_points = PackedVector2Array()
	tween = create_tween().set_loops()
	tween.tween_method(draw_tween,COLOR_1,COLOR_2,0.5)
	tween.tween_method(draw_tween,COLOR_2,COLOR_1,0.5)
	
func _draw() -> void:
	if has_valid_points:
		if arrow_points.size() == 3:
			draw_colored_polygon(arrow_points, curve_color)
		draw_polyline(points, curve_color, curve_width, true)
	pass
	
func clear_arrow()->void:
	visible = false
	if tween:
		tween.kill()

func draw_tween(color):
	curve_color = color
	queue_redraw()
