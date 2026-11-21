## 层视差换算：两个矢量叠加——①推离（沿指针反向、按深度线性）②吸向（朝鼠标、按深度平方）。
## 无状态、不持有节点引用：调用方自己取指针、自己保存基准，因此与背景场景互不依赖。
extends Object

## 指针归一化：屏幕中心为 0、视口边缘为 ±1，死区内恒为 0。
## @pure
static func normalize_pointer(mouse_position: Vector2, viewport_size: Vector2, deadzone: float = 0.08) -> Vector2:
	var half: Vector2 = viewport_size * 0.5
	if half.x <= 0.0 or half.y <= 0.0:
		return Vector2.ZERO
	var normalized: Vector2 = ((mouse_position - half) / half).clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))
	var distance: float = normalized.length()
	var zone: float = clamp(deadzone, 0.0, 0.99)
	if distance <= zone:
		return Vector2.ZERO
	return normalized * ((distance - zone) / (1.0 - zone))

## 矢量一·推离：与指针相对屏幕中心的方向相反，作用于整个 Face（层间差异很小）。
## depth_mix 控制深度对推离的影响，取值范围 0 至 1；0.15 表示最远与最近层只差约 10%。
## 指针在右上角时，返回指向左下。
## @pure
static func push_vector(pointer: Vector2, depth: float, amplitude: float, depth_mix: float = 0.15) -> Vector2:
	var mix: float = clampf(depth_mix, 0.0, 1.0)
	var depth_factor: float = 1.0 - mix * (1.0 - clampf(depth, 0.0, 1.0))
	return -pointer * amplitude * depth_factor

## 矢量二·吸向：由层中心指向鼠标，强度按深度的 power 次方缩放（默认 2.5，层间差异大）。
## 层中心与鼠标重合时为零。
## @pure
static func pull_vector(layer_center: Vector2, mouse_position: Vector2, depth: float, amplitude: float, power: float = 2.5) -> Vector2:
	var delta: Vector2 = mouse_position - layer_center
	var distance: float = delta.length()
	if distance <= 0.001:
		return Vector2.ZERO
	return delta / distance * amplitude * pow(max(depth, 0.0), power)

## 把屏幕像素位移折回局部坐标并对齐整数像素。
## @pure
static func offset_for(screen_offset: Vector2, item_scale: float = 1.0) -> Vector2:
	var scale_factor: float = item_scale if item_scale > 0.0 else 1.0
	return screen_offset.round() / scale_factor

## 按层中心到鼠标的距离求缩放：近处为 1，达到影响半径时为 min_scale。
## @pure
static func scale_for(layer_center: Vector2, mouse_position: Vector2, radius: float, min_scale: float) -> float:
	if radius <= 0.0:
		return 1.0
	return lerpf(1.0, min_scale, clampf(layer_center.distance_to(mouse_position) / radius, 0.0, 1.0))
