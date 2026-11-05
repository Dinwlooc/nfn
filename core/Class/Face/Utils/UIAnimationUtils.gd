@abstract
extends Object
class_name UIAnimationUtils
#==consts==
## 在smooth_move_animation中使用时，使任意6帧(0.1s)中的总移动与目标距离近似为黄金比例
const DEFAULT_SPEED: float = 0.07704
# ## 上述常数的前导因子。
# const  GOLDEN_SPEED_3FRAMES = 0.14935

#==motion==
## 平滑移动动画（逐帧逼近目标点）
## @pure
static func smooth_move_animation(
	current_position: Vector2,
	target_position: Vector2,
	smooth_move_speed: float = DEFAULT_SPEED
	) -> Vector2:
	if smooth_move_speed >= 1.0:
		return target_position
	if smooth_move_speed <= 0.0:
		return current_position
	var coefficient: float = smooth_move_speed
	var new_position: Vector2 = current_position
	var delta: Vector2 = target_position - current_position
	if !is_zero_approx(delta.x):
		new_position.x += delta.x * coefficient
	if !is_zero_approx(delta.y):
		new_position.y += delta.y * coefficient
	return new_position
## 简单的多属性Tween工具。
## 项目的高级UI动画一般不使用它，而是完整写出Tween编排流程，以提高性能表现。
## @atomic
static func tween_animations(node:Node,list:Dictionary[NodePath,Variant],time:float = 0.5,trans_type:Tween.TransitionType = Tween.TRANS_CUBIC,ease_type = Tween.EASE_OUT)->Tween:
	var tween:Tween = node.create_tween().set_parallel()
	if list:
		for key in list:
			tween.tween_property(node,key,list[key],time).set_trans(trans_type).set_ease(ease_type)
	return tween
#==assembly==
## 矩形补间：把 Control 的 position 与 size 并行补间到目标。
## 装配方法只填充传入的 tween，不创建 tween、不持有槽位、不判条件。
## @atomic
static func do_rect(
	tween: Tween,
	control: Control,
	target_position: Vector2,
	target_size: Vector2,
	duration: float = 0.2,
	trans_type: Tween.TransitionType = Tween.TRANS_CUBIC,
	ease_type: Tween.EaseType = Tween.EASE_OUT
) -> void:
	tween.set_parallel(true)
	tween.tween_property(control, ^"position", target_position, duration).set_trans(trans_type).set_ease(ease_type)
	tween.tween_property(control, ^"size", target_size, duration).set_trans(trans_type).set_ease(ease_type)
#==slots==
## 替换补间槽位：kill 旧补间，把新补间交还给槽位字段。空补间由调用点的卫语句拦住。
## 表现层每类动画只占一个槽位，同一槽位任一时刻只保留一条补间。
## @atomic
static func replace_tween(previous: Tween, next: Tween) -> Tween:
	if not next:
		return previous
	if previous and previous.is_valid():
		previous.kill()
	return next
## 清空补间槽位：kill 槽位里的补间并返回 null，供槽位字段直接赋值。
## @atomic
static func clear_tween(previous: Tween) -> Tween:
	if previous and previous.is_valid():
		previous.kill()
	return null

#==layout==
## 计算在容器内平均分布的一组坐标
## @atomic
static func generate_coordinates(card_container_position:Vector2,card_container_size:Vector2,card_count:int = 1) -> PackedVector2Array:
	if card_count == 0:
		return []
	var width: float = card_container_size.x
	var height: float = card_container_size.y
	var y_center: float = height / 2
	if card_count == 1:
		return [Vector2(width / 2, y_center)+card_container_position]
	var coordinates:PackedVector2Array = []
	for i in range(card_count):
		var x: float = ((i as float + 1) / (card_count + 1)) * width
		coordinates.append(Vector2(x, y_center)+card_container_position)
	return coordinates
## 使用前要注意主题资源的共享性。需要时应当前提对主题资源进行唯一化。
## @atomic
static func blink_stylebox_bg_color(block: Panel, from_color: Color, to_color: Color,  half_duration: float = 0.1 , times: int = 2) -> Tween:
	var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel") as StyleBoxFlat
	if not stylebox:
		return null
	var tween: Tween = block.create_tween()
	tween.set_parallel(false)
	for i in range(times):
		tween.tween_property(stylebox, ^"bg_color", to_color, half_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(stylebox, ^"bg_color", from_color, half_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(stylebox, ^"bg_color", to_color, half_duration)
	return tween

## 颜色闪烁动画（from ↔ to 往返 times 次后停在 from）
## @atomic
static func blink_color(rect: ColorRect, from_color: Color, to_color: Color, half_duration: float = 0.1, times: int = 2) -> Tween:
	var tween: Tween = rect.create_tween()
	tween.set_parallel(false)
	for i in range(times):
		tween.tween_property(rect, ^"color", to_color, half_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
		tween.tween_property(rect, ^"color", from_color, half_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(rect, ^"color", to_color, half_duration)
	return tween
## 根据数量计算缩放因子（适用于手牌、防御区等）
## @pure
static func compute_scale_factor(count: int, min_count: int = 8, max_count: int = 24, min_scale: float = 0.75, max_scale: float = 1.0) -> float:
	if count <= min_count:
		return max_scale
	if count >= max_count:
		return min_scale
	return max_scale - (count - min_count) / (max_count - min_count) * (max_scale - min_scale)
