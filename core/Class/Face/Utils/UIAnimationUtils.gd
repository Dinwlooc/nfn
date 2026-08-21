extends RefCounted
class_name UIAnimationUtils

const  DEFAULT_SPEED = 0.07704  # 使任意6帧(0.1s)中的总移动与目标距离呈现为黄金比例
const  GOLDEN_SPEED_3FRAMES = 0.14935

static func smooth_move_animation(
	current_position: Vector2,
	target_position: Vector2,
	smooth_move_speed: float = DEFAULT_SPEED
	) -> Vector2:
	if smooth_move_speed >= 1.0:
		return target_position
	if smooth_move_speed <= 0.0:
		return current_position
	var coefficient = smooth_move_speed
	var new_position = current_position
	var delta = target_position - current_position
	if !is_zero_approx(delta.x):
		new_position.x += delta.x * coefficient
	if !is_zero_approx(delta.y):
		new_position.y += delta.y * coefficient
	return new_position

static func tween_animations(node:Node,list:Dictionary[NodePath,Variant],time:float = 0.5,trans_type:Tween.TransitionType = Tween.TRANS_CUBIC,ease_type = Tween.EASE_OUT)->Tween:
	var tween:Tween = node.create_tween()
	if list:
		for key in list:
			tween.tween_property(node,key,list[key],time).set_trans(trans_type).set_ease(ease_type)
	return tween

static func generate_coordinates(card_container_position:Vector2,card_container_size:Vector2,card_count:int = 1) -> PackedVector2Array:
	if card_count == 0:
		return []
	var width = card_container_size.x
	var height = card_container_size.y
	var y_center = height / 2
	if card_count == 1:
		return [Vector2(width / 2, y_center)+card_container_position]
	var coordinates:PackedVector2Array = []
	for i in range(card_count):
		var x = ((i as float + 1) / (card_count + 1)) * width
		coordinates.append(Vector2(x, y_center)+card_container_position)
	return coordinates

static func blink_stylebox_bg_color(block: Panel, from_color: Color, to_color: Color,  half_duration: float = 0.1 , times: int = 2) -> Tween:
	var stylebox = block.get_theme_stylebox(&"panel") as StyleBoxFlat
	if not stylebox:
		return null
	var tween = block.create_tween()
	tween.set_parallel(false)
	for i in range(times):
		tween.tween_property(stylebox, ^"bg_color", to_color, half_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(stylebox, ^"bg_color", from_color, half_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(stylebox, ^"bg_color", to_color, half_duration)
	return tween

static func blink_color(rect: ColorRect, from_color: Color, to_color: Color, half_duration: float = 0.1, times: int = 2) -> Tween:
	var tween = rect.create_tween()
	tween.set_parallel(false)
	for i in range(times):
		tween.tween_property(rect, ^"color", to_color, half_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(rect, ^"color", from_color, half_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(rect, ^"color", to_color, half_duration)
	return tween

## 根据数量计算缩放因子（适用于手牌、防御区等）
static func compute_scale_factor(count: int, min_count: int = 8, max_count: int = 24, min_scale: float = 0.75, max_scale: float = 1.0) -> float:
	if count <= min_count:
		return max_scale
	if count >= max_count:
		return min_scale
	return max_scale - (count - min_count) / (max_count - min_count) * (max_scale - min_scale)
