extends Control

## 通用着色器实验室：按用例并排显示“基线 / 当前”，用例由数据定义，不绑定具体着色器。
## 每个用例声明场景、显示子树、目标 CanvasItem、着色器文件名、基线/当前参数与要展示的参数名。
## 每次重建都重新实例化 res:// 真实场景，因此同名场景/贴图/材质被覆盖后会直接反映。
const PANEL_SIZE: Vector2 = Vector2(760.0, 427.5)
const PANEL_Y: float = 96.0
const LEFT_X: float = 30.0
const RIGHT_X: float = 810.0

## 一条着色器用例；参数覆盖为 instance uniform 键值。
## @record
class ShaderCase:
	var label: String
	var scene_path: String
	var display_selector: String
	var target_selector: String
	var shader_file: String
	var baseline_params: Dictionary[StringName, Variant]
	var current_params: Dictionary[StringName, Variant]
	var readout_params: PackedStringArray
	var display_scale: float

	func _init(
		case_label: String,
		case_scene_path: String,
		case_display_selector: String,
		case_target_selector: String,
		case_shader_file: String,
		case_baseline_params: Dictionary[StringName, Variant],
		case_current_params: Dictionary[StringName, Variant],
		case_readout_params: PackedStringArray,
		case_display_scale: float
	) -> void:
		label = case_label
		scene_path = case_scene_path
		display_selector = case_display_selector
		target_selector = case_target_selector
		shader_file = case_shader_file
		baseline_params = case_baseline_params
		current_params = case_current_params
		readout_params = case_readout_params
		display_scale = case_display_scale

var _cases: Array[ShaderCase] = []
var _case_index: int = 0
var _pair_root: Control
var _title_label: Label
var _left_caption: Label
var _right_caption: Label
var _status_label: Label

func _ready() -> void:
	_hide_transition()
	_build_cases()
	_build_static_ui()
	_build_pair(_case_index)

func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		get_tree().quit()
		return
	if key.keycode == KEY_R:
		_build_pair(_case_index)
		return
	var case_number: int = key.keycode - KEY_1
	if case_number < 0 or case_number >= _cases.size():
		return
	_case_index = case_number
	_build_pair(_case_index)

## 组装用例表；新增着色器只在这里追加数据。
## @internal
func _build_cases() -> void:
	_cases = []
	var bloom_readout: PackedStringArray = PackedStringArray([
		"threshold_min", "threshold_softness", "bloom_intensity", "spread", "sample_mip", "sample_jitter",
	])
	_cases.append(ShaderCase.new(
		"泛光 · 菜单背景",
		"res://core/tscn/meum/main_meum.tscn",
		"MeumControl/Backgound",
		"ColorRect",
		"bloom.gdshader",
		_override(&"enable_bloom", false),
		_override(&"enable_bloom", true),
		bloom_readout,
		0.475,
	))
	_cases.append(ShaderCase.new(
		"泛光 · 区域背景",
		"res://resource/default/assets/Area/areaface/backgound.tscn",
		".",
		"ColorRect",
		"bloom.gdshader",
		_override(&"enable_bloom", false),
		_override(&"enable_bloom", true),
		bloom_readout,
		0.475,
	))

## 生成单参数覆盖表。
## @pure
func _override(key: StringName, value: Variant) -> Dictionary[StringName, Variant]:
	var params: Dictionary[StringName, Variant] = {}
	params[key] = value
	return params

## 隐藏转场单例的全屏黑幕；否则非菜单场景的测试场景整幅全黑。
## @side_effect
func _hide_transition() -> void:
	GlobalTransition.fade_out(0.0)

## @internal
func _build_static_ui() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.03, 0.04, 0.06)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_title_label = Label.new()
	_title_label.position = Vector2(30.0, 18.0)
	_title_label.add_theme_font_size_override("font_size", 26)
	add_child(_title_label)

	_left_caption = _make_caption(Vector2(LEFT_X, 58.0))
	_right_caption = _make_caption(Vector2(RIGHT_X, 58.0))

	var divider: ColorRect = ColorRect.new()
	divider.color = Color(0.12, 0.16, 0.2)
	divider.position = Vector2(797.0, PANEL_Y)
	divider.size = Vector2(6.0, PANEL_SIZE.y)
	add_child(divider)

	_status_label = Label.new()
	_status_label.position = Vector2(30.0, 545.0)
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.9))
	add_child(_status_label)

	var help: Label = Label.new()
	help.position = Vector2(30.0, 610.0)
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_color", Color(0.55, 0.62, 0.7))
	help.text = "1-%d 选择用例    R 重新加载（模组/场景变更后）    Esc 退出" % _cases.size()
	add_child(help)

## @internal
func _make_caption(pos: Vector2) -> Label:
	var label: Label = Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)
	return label

## @internal
func _build_pair(index: int) -> void:
	if _pair_root != null:
		_pair_root.queue_free()
		_pair_root = null
	var case_data: ShaderCase = _cases[index]
	var packed: PackedScene = load(case_data.scene_path) as PackedScene
	if packed == null:
		_set_status("无法加载场景：%s" % case_data.scene_path)
		return
	var baseline: Control = _extract_display(packed, case_data.display_selector, case_data.display_scale)
	var current: Control = _extract_display(packed, case_data.display_selector, case_data.display_scale)
	if baseline == null or current == null:
		if baseline != null:
			baseline.queue_free()
		if current != null:
			current.queue_free()
		_set_status("无法提取显示子树：%s" % case_data.display_selector)
		return

	_pair_root = Control.new()
	_pair_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_pair_root)
	_attach_panel(baseline, Vector2(LEFT_X, PANEL_Y))
	_attach_panel(current, Vector2(RIGHT_X, PANEL_Y))

	var baseline_target: CanvasItem = _find_target(baseline, case_data)
	var current_target: CanvasItem = _find_target(current, case_data)
	if baseline_target == null or current_target == null:
		_set_status("目标节点或着色器不匹配：%s" % case_data.shader_file)
		return
	_apply_params(baseline_target, case_data.baseline_params)
	_apply_params(current_target, case_data.current_params)
	_title_label.text = "着色器实验室 · %s" % case_data.label
	_left_caption.text = "基线（%s）" % _format_overrides(case_data.baseline_params)
	_right_caption.text = "当前（%s）" % _format_overrides(case_data.current_params)
	_status_label.text = "%s  |  %s" % [
		case_data.shader_file,
		_format_readout(current_target, case_data.readout_params),
	]

## 从场景实例中摘出显示子树；保留场景内材质与实例参数。
## @external
func _extract_display(packed: PackedScene, selector: String, scale_factor: float) -> Control:
	var source: Node = packed.instantiate()
	var display: Node = source if selector == "." else source.get_node_or_null(selector)
	if display == null or not display is Control:
		source.queue_free()
		return null
	var control: Control = display as Control
	var original_scale: Vector2 = control.scale
	if control != source:
		var parent: Node = control.get_parent()
		parent.remove_child(control)
		source.queue_free()
	_clear_owner(control)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.position = Vector2.ZERO
	control.scale = original_scale * scale_factor
	return control

## 在显示子树里找到带指定着色器的目标节点。
## @pure
func _find_target(display: Node, case_data: ShaderCase) -> CanvasItem:
	var target: Node = display if case_data.target_selector == "." else display.get_node_or_null(case_data.target_selector)
	if target == null or not target is CanvasItem:
		return null
	var canvas_item: CanvasItem = target as CanvasItem
	var material: ShaderMaterial = canvas_item.material as ShaderMaterial
	if material == null or material.shader == null:
		return null
	var shader_path: String = material.shader.resource_path
	if not shader_path.ends_with(case_data.shader_file):
		return null
	return canvas_item

## @external
func _apply_params(target: CanvasItem, params: Dictionary[StringName, Variant]) -> void:
	for key: StringName in params:
		target.set_instance_shader_parameter(key, params[key])

## @pure
func _format_overrides(params: Dictionary[StringName, Variant]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for key: StringName in params:
		parts.append("%s=%s" % [key, _format_value(params[key])])
	return ", ".join(parts)

## 读取实际生效值：实例覆盖优先，其次材质参数；都没有则标“默认”。
## @pure
func _format_readout(target: CanvasItem, names: PackedStringArray) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for name: String in names:
		var key: StringName = StringName(name)
		var value: Variant = target.get_instance_shader_parameter(key)
		if value == null:
			var material: ShaderMaterial = target.material as ShaderMaterial
			if material != null:
				value = material.get_shader_parameter(key)
		parts.append("%s=%s" % [key, _format_value(value) if value != null else "默认"])
	return ", ".join(parts)

## 清除旧场景的 owner，避免跨场景重新挂载时 owner 不一致警告。
## @external
func _clear_owner(node: Node) -> void:
	node.owner = null
	for child: Node in node.get_children():
		_clear_owner(child)

## @pure
func _format_value(value: Variant) -> String:
	if value is float:
		return "%.3f" % value
	if value is int:
		return "%d" % value
	if value is bool:
		return "true" if value else "false"
	return str(value)

## @external
func _attach_panel(display: Control, pos: Vector2) -> void:
	var panel: Control = Control.new()
	panel.position = pos
	panel.size = PANEL_SIZE
	panel.clip_contents = true
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pair_root.add_child(panel)
	panel.add_child(display)
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE

## @internal
func _set_status(text: String) -> void:
	_status_label.text = text
