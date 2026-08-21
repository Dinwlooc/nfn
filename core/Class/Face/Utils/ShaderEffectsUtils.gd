extends RefCounted
class_name ShaderEffectsUtils

## ===== 闪光 =====
## 使节点以指定颜色闪烁至原色（强度渐变至0）
static func flash_color(node: CanvasItem, color: Color, duration: float = 0.3, max_intensity: float = 1.0) -> void:
	node.set_instance_shader_parameter(&"flash_color", color)
	node.set_instance_shader_parameter(&"flash_intensity", max_intensity)
	var tween = node.create_tween()
	tween.tween_method(
		func(v): node.set_instance_shader_parameter(&"flash_intensity", v),
		max_intensity, 0.0, duration
	).set_ease(Tween.EASE_OUT)

## 使节点闪烁红色（便捷方法）
static func flash_red(node: CanvasItem, duration: float = 0.3, max_intensity: float = 1.0) -> void:
	flash_color(node, Color.RED, duration, max_intensity)

## ===== 透明度 =====
## 立即设置透明度
static func set_alpha(node: CanvasItem, alpha: float) -> void:
	node.set_instance_shader_parameter(&"alpha", alpha)

## 在已有 Tween 中添加透明度渐变
static func tween_alpha(node: CanvasItem, tween: Tween, target_alpha: float, duration: float) -> void:
	var start_alpha = node.get_instance_shader_parameter(&"alpha")
	if start_alpha == null:
		start_alpha = 1.0
	tween.tween_method(
		func(v): node.set_instance_shader_parameter(&"alpha", v),
		start_alpha, target_alpha, duration
	)

## ===== 泛光 =====
## 设置亮度阈值（min 有效，max 参数保留用于兼容）
static func set_bloom_range(node: CanvasItem, min_val: float, max_val: float = 1.0) -> void:
	node.set_instance_shader_parameter(&"threshold_min", min_val)
	# threshold_max 已废弃

## 设置泛光强度
static func set_bloom_intensity(node: CanvasItem, intensity: float) -> void:
	node.set_instance_shader_parameter(&"bloom_intensity", intensity)

## 设置泛光扩散半径（对应 spread）
static func set_bloom_radius(node: CanvasItem, radius: float) -> void:
	node.set_instance_shader_parameter(&"spread", radius)

## 启用/禁用脉冲并设置速度
static func set_bloom_pulse(node: CanvasItem, enabled: bool, speed: float = 2.0) -> void:
	node.set_instance_shader_parameter(&"enable_pulse", enabled)
	node.set_instance_shader_parameter(&"pulse_speed", speed)

## 播放强度脉冲动画（从当前值到目标值再返回）
static func pulse_bloom_intensity(node: CanvasItem, target: float, duration: float = 0.5, ping_pong: bool = true) -> void:
	var start = node.get_instance_shader_parameter(&"bloom_intensity") as float
	var tween := node.create_tween()
	tween.set_parallel(false)
	tween.tween_method(
		func(v): node.set_instance_shader_parameter(&"bloom_intensity", v),
		start, target, duration * 0.5
	).set_ease(Tween.EASE_OUT)
	if ping_pong:
		tween.tween_method(
			func(v): node.set_instance_shader_parameter(&"bloom_intensity", v),
			target, start, duration * 0.5
		).set_ease(Tween.EASE_IN)

## ===== 交叉淡化 =====
## 执行纹理交叉淡化动画（从 early_texture 渐变为当前纹理）
static func crossfade_texture(node: CanvasItem, early_texture: Texture2D, duration: float = 0.5) -> void:
	node.set_instance_shader_parameter(&"enable_crossfade", true)
	node.set_instance_shader_parameter(&"early_texture", early_texture)
	node.set_instance_shader_parameter(&"crossfade_amount", 0.0)
	var tween := node.create_tween()
	tween.tween_method(
		func(v): node.set_instance_shader_parameter(&"crossfade_amount", v),
		0.0, 1.0, duration
	).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		node.set_instance_shader_parameter(&"enable_crossfade", false)
	)

## 执行精灵帧交叉淡化动画（过渡到 target_frame）
static func crossfade_sprite_frame(sprite: Sprite2D, target_frame: int, duration: float = 0.5) -> void:
	var current_frame := sprite.frame
	var hframes := sprite.hframes
	var vframes := sprite.vframes
	if hframes <= 0 or vframes <= 0:
		push_error("Sprite must have positive hframes and vframes for crossfade.")
		return
	# 关闭普通交叉淡化，启用精灵帧交叉淡化
	sprite.set_instance_shader_parameter(&"enable_crossfade", false)
	sprite.set_instance_shader_parameter(&"enable_sprite_crossfade", true)
	sprite.set_instance_shader_parameter(&"early_frame", current_frame)
	sprite.set_instance_shader_parameter(&"current_frame", target_frame)
	sprite.set_instance_shader_parameter(&"hframes", hframes)
	sprite.set_instance_shader_parameter(&"vframes", vframes)
	sprite.set_instance_shader_parameter(&"sprite_crossfade_amount", 0.0)
	var tween := sprite.create_tween()
	tween.tween_method(
		func(v): sprite.set_instance_shader_parameter(&"sprite_crossfade_amount", v),
		0.0, 1.0, duration
	).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		sprite.frame = target_frame
		sprite.set_instance_shader_parameter(&"enable_sprite_crossfade", false)
	)

## ===== RGB 偏移 =====
## 设置三色偏移失真强度
static func set_rgb_shift_intensity(node: CanvasItem, intensity: float) -> void:
	node.set_instance_shader_parameter(&"distortion_intensity", intensity)
