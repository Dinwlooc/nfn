##使用该类前需为目标CanvasItem手动配置好ShaderMaterial，其应使用官方的Shader
extends RefCounted
class_name ShaderEffectsUtils

## 使节点以指定颜色闪烁至原色，兼容flash_color.gdshader
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

##兼容bloom.gdshader
static func set_bloom_range(node: CanvasItem, min_val: float, max_val: float) -> void:
	var mat := node.material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter(&"threshold_min", min_val)
	mat.set_shader_parameter(&"threshold_max", max_val)

## 设置泛光强度，兼容bloom.gdshader
static func set_bloom_intensity(node: CanvasItem, intensity: float) -> void:
	var mat := node.material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter(&"intensity", intensity)

## 设置泛光半径，兼容bloom.gdshader
static func set_bloom_radius(node: CanvasItem, radius: float) -> void:
	var mat := node.material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter(&"radius", radius)

## 启用/禁用脉冲并设置速度，兼容bloom.gdshader
static func set_bloom_pulse(node: CanvasItem, enabled: bool, speed: float = 2.0) -> void:
	var mat := node.material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter(&"enable_pulse", enabled)
	mat.set_shader_parameter(&"pulse_speed", speed)

## 播放强度脉冲动画（从当前值到目标值再返回），兼容bloom.gdshader
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
