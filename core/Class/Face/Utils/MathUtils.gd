extends RefCounted
class_name MathUtils

static func generate_sine_table(table_size: int) -> Array:
	var sine_table = []
	sine_table.resize(table_size)
	var quarter = table_size / 4
	for i in range(0, quarter + 1):
		sine_table[i] = sin(TAU * i / table_size)
	for i in range(1, quarter):
		sine_table[quarter + i] = sine_table[quarter - i]
	for i in range(0, 2 * quarter):
		sine_table[2 * quarter + i] = -sine_table[i]
	return sine_table
## 生成连接两点的平滑曲线
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
