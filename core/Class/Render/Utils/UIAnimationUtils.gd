extends RefCounted
class_name UIAnimationUtils
#以全局脚本的形式提供UI动画插值函数。
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
	# 获取区域尺寸
	var width = card_container_size.x
	var height = card_container_size.y
	# 计算垂直居中y坐标
	var y_center = height / 2
	# 处理单张卡牌特殊情况
	if card_count == 1:
		return [Vector2(width / 2, y_center)+card_container_position]
	# 计算等间距分布
	var coordinates:PackedVector2Array = []
	for i in range(card_count):
		# 使用线性插值计算位置 (0到width的等比位置)
		var x = ((i as float + 1) / (card_count + 1)) * width
		coordinates.append(Vector2(x, y_center)+card_container_position)
	return coordinates
