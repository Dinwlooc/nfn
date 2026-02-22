extends RefCounted
class_name ShaderEffectsUtils

## 使节点以指定颜色闪烁至原色，兼容 flash_color.gdshader
static func flash_color(node: CanvasItem, color: Color, duration: float = 0.3, max_intensity: float = 1.0) -> void:
	var material: ShaderMaterial = node.material as ShaderMaterial
	if not material:
		return
	material.set_shader_parameter(&"flash_color", color)
	material.set_shader_parameter(&"flash_intensity", max_intensity)
	var tween = node.create_tween()
	tween.tween_method(
		func(v): material.set_shader_parameter(&"flash_intensity", v),
		max_intensity, 0.0, duration
	).set_ease(Tween.EASE_OUT)

## 使节点闪烁红色（调用 flash_color 的便捷方法）
static func flash_red(node: CanvasItem, duration: float = 0.3, max_intensity: float = 1.0) -> void:
	flash_color(node, Color.RED, duration, max_intensity)

## 立即设置节点的透明度（通过着色器 alpha 参数）
static func set_alpha(node: CanvasItem, alpha: float) -> void:
	var material := node.material as ShaderMaterial
	if not material:
		return
	material.set_shader_parameter(&"alpha", alpha)

## 在指定的 Tween 中添加透明度渐变动画
static func tween_alpha(node: CanvasItem, tween: Tween, target_alpha: float, duration: float) -> void:
	var material :ShaderMaterial= node.material as ShaderMaterial
	if not material:
		return
	var start_alpha :float = material.get_shader_parameter(&"alpha")
	if start_alpha == null:
		start_alpha = 1.0
	tween.tween_method(
		func(v): material.set_shader_parameter(&"alpha", v),
		start_alpha, target_alpha, duration
	)

## 兼容 bloom.gdshader
static func set_bloom_range(node: CanvasItem, min_val: float, max_val: float) -> void:
	var mat := node.material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter(&"threshold_min", min_val)
	mat.set_shader_parameter(&"threshold_max", max_val)

## 设置泛光强度，兼容 bloom.gdshader
static func set_bloom_intensity(node: CanvasItem, intensity: float) -> void:
	var mat := node.material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter(&"intensity", intensity)

## 设置泛光半径，兼容 bloom.gdshader
static func set_bloom_radius(node: CanvasItem, radius: float) -> void:
	var mat := node.material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter(&"radius", radius)

## 启用/禁用脉冲并设置速度，兼容 bloom.gdshader
static func set_bloom_pulse(node: CanvasItem, enabled: bool, speed: float = 2.0) -> void:
	var mat := node.material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter(&"enable_pulse", enabled)
	mat.set_shader_parameter(&"pulse_speed", speed)

## 播放强度脉冲动画（从当前值到目标值再返回），兼容 bloom.gdshader
static func pulse_bloom_intensity(node: CanvasItem, target: float, duration: float = 0.5, ping_pong: bool = true) -> void:
	var mat := node.material as ShaderMaterial
	if not mat:
		return
	var start := mat.get_shader_parameter(&"intensity") as float
	var tween := node.create_tween()
	tween.set_parallel(false)
	tween.tween_method(
		func(v): mat.set_shader_parameter(&"intensity", v),
		start, target, duration * 0.5
	).set_ease(Tween.EASE_OUT)
	if ping_pong:
		tween.tween_method(
			func(v): mat.set_shader_parameter(&"intensity", v),
			target, start, duration * 0.5
		).set_ease(Tween.EASE_IN)

# ===== 新增：交叉淡化功能 =====

## 执行一次交叉淡化动画：从早期纹理渐变为当前纹理，动画结束后自动关闭交叉淡化效果。
## 兼容添加了交叉淡化参数的着色器（需包含 enable_crossfade, early_texture, crossfade_amount）。
static func crossfade_texture(node: CanvasItem, early_texture: Texture2D, duration: float = 0.5) -> void:
	var material := node.material as ShaderMaterial
	if not material:
		return
	material.set_shader_parameter(&"enable_crossfade", true)
	material.set_shader_parameter(&"early_texture", early_texture)
	material.set_shader_parameter(&"crossfade_amount", 0.0)
	var tween := node.create_tween()
	tween.tween_method(
		func(v): material.set_shader_parameter(&"crossfade_amount", v),
		0.0, 1.0, duration
	).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		material.set_shader_parameter(&"enable_crossfade", false)
	)

static func crossfade_sprite_frame(sprite: Sprite2D, target_frame: int, duration: float = 0.5) -> void:
	var material := sprite.material as ShaderMaterial
	if not material:
		push_error("Sprite has no ShaderMaterial assigned.")
		return
	var current_frame := sprite.frame
	var hframes := sprite.hframes
	var vframes := sprite.vframes
	if hframes <= 0 or vframes <= 0:
		push_error("Sprite must have positive hframes and vframes for crossfade.")
		return
	material.set_shader_parameter(&"enable_sprite_crossfade", true)
	material.set_shader_parameter(&"early_frame", current_frame)
	material.set_shader_parameter(&"current_frame", target_frame)
	material.set_shader_parameter(&"hframes", hframes)
	material.set_shader_parameter(&"vframes", vframes)
	material.set_shader_parameter(&"sprite_crossfade_amount", 0.0)
	var tween := sprite.create_tween()
	tween.tween_method(
		func(v): material.set_shader_parameter(&"sprite_crossfade_amount", v),
		0.0, 1.0, duration
	).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		sprite.frame = target_frame
		material.set_shader_parameter(&"enable_sprite_crossfade", false)
	)
