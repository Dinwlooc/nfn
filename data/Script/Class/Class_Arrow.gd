extends Control

func create_smooth_curve(start: Vector2, end: Vector2) -> Curve2D:
	var curve = Curve2D.new()
	var control1 = start + Vector2(0,(end.y - start.y)*0.5) 
	var control2 = end - Vector2(0,(end.y - start.y)*0.5)
	curve.add_point(start,Vector2.ZERO,control1) 
	curve.add_point(end,control2)
	return curve
