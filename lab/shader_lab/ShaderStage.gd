## 着色器舞台：一张图 + 一份着色器材质 + 一张参数表，是处理器组装与实验室呈现的共同载体。
## 只认组合资源，不认识界面，也不读配置表。
extends TextureRect
class_name ShaderStage

## 当前组合；null 表示尚未按组合构建
var combo: ShaderLabPreset = null

## 承载实例参数的材质
var _mat: ShaderMaterial = null

func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## 取承载参数的材质；未构建时为 null
func material_of() -> ShaderMaterial:
	return _mat

## 当前着色器文件名；未挂着色器时为空
func shader_file_name() -> String:
	if _mat == null or _mat.shader == null:
		return ""
	return _mat.shader.resource_path.get_file()

## 按组合重建：贴图、着色器、参数一次到位；返回着色器是否可用
func compose(p_combo: ShaderLabPreset) -> bool:
	combo = p_combo
	if p_combo == null:
		return false
	if not p_combo.texture_path.is_empty():
		var tex: Texture2D = load(p_combo.texture_path) as Texture2D
		if tex != null:
			texture = tex
	if _mat == null:
		_mat = ShaderMaterial.new()
	# 组合换到「纯图片」时旧着色器必须摘掉，否则复用舞台会沿用上一份
	_mat.shader = null
	if not p_combo.shader_path.is_empty():
		_mat.shader = load(p_combo.shader_path) as Shader
	material = _mat
	for key: StringName in p_combo.params:
		set_instance_shader_parameter(key, p_combo.params[key])
	return _mat.shader != null

## 写一个实例 uniform，并记回组合
func set_param(key: StringName, value: Variant) -> void:
	set_instance_shader_parameter(key, value)
	if combo != null:
		combo.params[key] = value

## 读实际生效值：实例覆盖 → 材质参数 → null（表示默认）
func param_value(key: StringName) -> Variant:
	var value: Variant = get_instance_shader_parameter(key)
	if value == null and _mat != null:
		value = _mat.get_shader_parameter(key)
	return value

## 复位：按当前组合重新施加，丢弃临时改动
func reset() -> void:
	if combo != null:
		compose(combo)
