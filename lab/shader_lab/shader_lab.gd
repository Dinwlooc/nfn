## 着色器实验室：双资源实验室，图片与着色器各自独立选择，右侧舞台由处理器按组合组装；
## 左侧只把图原样呈现，不给着色器——基线严格来说就是只读图片资源的效果。
## 对拍只有自由形态：选参考图与着色器，不预置呈现组合；
## 本类只声明界面、选择器与参数面板；组合的组装归处理器。
extends FaceLab
## 舞台场景：处理器按它实例化右侧展示节点
const STAGE_SCENE: String = "res://lab/shader_lab/shader_stage.tscn"
const PANEL_SIZE: Vector2 = Vector2(760.0, 427.5)
const PANEL_Y: float = 96.0
const LEFT_X: float = 30.0
const RIGHT_X: float = 810.0
## 着色器候选目录（递归扫描 .gdshader）
const SHADER_DIR: String = "res://resource/default/shader/gdshader/"
## 参考图候选目录（递归扫描已导入的位图）
const TEXTURE_DIRS: Array[String] = ["res://resource/default/assets/"]

## 着色器声明行的解析式：捕获类型名、变量名、hint 段与默认值
const UNIFORM_PATTERN: String = "\\s*(?:instance\\s+)?uniform\\s+([A-Za-z_][A-Za-z0-9_]*)\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*(?::\\s*([^=]*))?(?:=\\s*([^;]*))?;"
## hint_range 的上下界
const RANGE_PATTERN: String = "hint_range\\(\\s*(-?[0-9.]+)\\s*,\\s*(-?[0-9.]+)"
## 着色器源里的 include 行（uniform 可能写在 .gdshaderinc 里）
const INCLUDE_PATTERN: String = "#include\\s+\"([^\"]+)\""

## 一条着色器参数：名称、类型字面量与取值范围（来自源文件，不靠引擎反射）。
## @record
class ParamSpec:
	var key: StringName
	var type_name: String
	var min_value: float
	var max_value: float
	var default_value: Variant

	func _init(p_key: StringName, p_type: String, p_min: float, p_max: float, p_default: Variant) -> void:
		key = p_key
		type_name = p_type
		min_value = p_min
		max_value = p_max
		default_value = p_default

var _pair_root: Control
var _title_label: Label
var _left_caption: Label
var _right_caption: Label
var _status_label: Label
var _help_label: Label
## 参考图与着色器选择器
var _texture_option: OptionButton
var _shader_option: OptionButton
## 扫描到的候选路径
var _texture_paths: PackedStringArray = PackedStringArray()
var _shader_paths: PackedStringArray = PackedStringArray()
var _texture_index: int = 0
var _shader_index: int = 0
## 参数面板（自由对拍）
var _param_scroll: ScrollContainer
var _param_box: VBoxContainer
## 左参考图与右舞台（舞台由处理器组装）
var _free_ref: TextureRect
var _free_target: ShaderStage
var _free_material: ShaderMaterial

#==生命周期==
## 提供处理器：着色器舞台由它组装
## @override
func _create_handler() -> LabHandler:
	return ShaderLabHandler.new(data)

## 判据入口：屏蔽 _ready 时由空壳调用，只建参数库、处理器与界面
## @override
func _lab_boot() -> void:
	data = LabData.new()
	if lab_id.is_empty():
		lab_id = &"shader"
	_ensure_handler()
	_build_gui()

## 取处理器：界面先于基类创建处理器时补建
## @internal
func _ensure_handler() -> ShaderLabHandler:
	if handler == null:
		handler = _create_handler()
	return handler as ShaderLabHandler

## 建界面：静态框架 + 先进自由对拍
## @override
func _build_gui() -> void:
	if lab_id.is_empty():
		lab_id = &"shader"
	_build_static_ui()
	_build_free_pair()


## 重载后重建当前模式
## @override
func _on_reload() -> void:
	if _free_target != null:
		_apply_free_shader()

#==界面==
## 建静态界面：标题、双栏、选择器、参数面板、状态与帮助
## @internal
func _build_static_ui() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.03, 0.04, 0.06)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(divider)

	_build_selectors()
	_build_param_panel()

	_status_label = Label.new()
	_status_label.position = Vector2(RIGHT_X, 540.0)
	_status_label.size = Vector2(760.0, 88.0)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.9))
	add_child(_status_label)

	_help_label = Label.new()
	_help_label.position = Vector2(RIGHT_X, 632.0)
	_help_label.size = Vector2(760.0, 40.0)
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help_label.add_theme_font_size_override("font_size", 15)
	_help_label.add_theme_color_override("font_color", Color(0.55, 0.62, 0.7))
	_help_label.text = "选参考图 / 着色器 → 下方调参即时生效    R 重新加载    Esc 返回主菜单（独立运行时退出）"
	add_child(_help_label)

## 参考图与着色器选择器
## @internal
func _build_selectors() -> void:
	_shader_paths = _scan_shaders()
	_texture_paths = _scan_textures()
	var ref_label: Label = _make_caption(Vector2(LEFT_X, 578.0))
	ref_label.text = "参考图"
	_texture_option = OptionButton.new()
	_texture_option.position = Vector2(LEFT_X + 90.0, 574.0)
	_texture_option.size = Vector2(600.0, 32.0)
	_texture_option.item_selected.connect(_on_texture_selected)
	add_child(_texture_option)
	for path: String in _texture_paths:
		_texture_option.add_item(path.get_file())
	var shader_label: Label = _make_caption(Vector2(LEFT_X, 614.0))
	shader_label.text = "着色器"
	_shader_option = OptionButton.new()
	_shader_option.position = Vector2(LEFT_X + 90.0, 610.0)
	_shader_option.size = Vector2(600.0, 32.0)
	_shader_option.item_selected.connect(_on_shader_selected)
	add_child(_shader_option)
	for path: String in _shader_paths:
		_shader_option.add_item(path.get_file())

## 参数面板容器：左侧滚动区，控件按着色器声明动态生成
## @internal
func _build_param_panel() -> void:
	_param_scroll = ScrollContainer.new()
	_param_scroll.position = Vector2(LEFT_X, 652.0)
	_param_scroll.size = Vector2(740.0, 244.0)
	_param_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_param_scroll)
	_param_box = VBoxContainer.new()
	_param_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_param_box.add_theme_constant_override("separation", 6)
	_param_scroll.add_child(_param_box)

## @internal
func _make_caption(pos: Vector2) -> Label:
	var label: Label = Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", 18)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

#==自由对拍==
## 建容器：铺满全屏但不吃鼠标，避免盖住下拉与参数面板
## @internal
func _build_pair_root() -> void:
	_pair_root = Control.new()
	_pair_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pair_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_pair_root)

## 建自由对拍：左参考图原样、右舞台由处理器按当前组合组装
## @internal
func _build_free_pair() -> void:
	if _pair_root != null:
		_pair_root.queue_free()
		_pair_root = null
	_build_pair_root()
	_free_ref = TextureRect.new()
	_free_ref.size = PANEL_SIZE
	_free_ref.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_free_ref.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_free_target = _assemble_stage()
	if _free_target == null:
		_set_status("无法组装舞台：%s" % STAGE_SCENE)
		return
	_free_material = _free_target.material_of()
	_attach_panel(_free_ref, Vector2(LEFT_X, PANEL_Y))
	_attach_panel(_free_target, Vector2(RIGHT_X, PANEL_Y))
	_apply_free_texture()
	_apply_free_shader()

## 交给处理器组装一个舞台节点取出来；组装结果不入树，由实验室摆放
## @internal
func _assemble_stage() -> ShaderStage:
	var lab_handler: ShaderLabHandler = _ensure_handler()
	if lab_handler == null:
		return null
	var node: Node = lab_handler.assemble(&"free", STAGE_SCENE, {})
	if node == null:
		return null
	return lab_handler.take(&"free") as ShaderStage

## 把当前两份选择合成一个组合：图片 + 着色器 + 参数
## @pure
func _combo_from_selectors() -> ShaderLabPreset:
	var combo: ShaderLabPreset = ShaderLabPreset.new()
	if not _texture_paths.is_empty():
		combo.texture_path = _texture_paths[_texture_index]
	if not _shader_paths.is_empty():
		combo.shader_path = _shader_paths[_shader_index]
	return combo

## 按当前组合重建右侧舞台，并在操作参数库里留下这份组合
## @side_effect
func _compose_free() -> void:
	if _free_target == null:
		return
	var combo: ShaderLabPreset = _combo_from_selectors()
	var lab_handler: ShaderLabHandler = _ensure_handler()
	if lab_handler != null:
		lab_handler.apply(combo, _free_target)
	_free_material = _free_target.material_of()
	if _free_ref != null and _free_target.texture != null:
		_free_ref.texture = _free_target.texture
	if data != null:
		data.put_preset(&"free", combo)

## 把选中的参考图贴到两侧（左侧原图，右侧同图供着色器处理）
## @side_effect
func _apply_free_texture() -> void:
	if _free_ref == null or _free_target == null:
		return
	if _texture_paths.is_empty():
		_set_status("没有找到参考图：检查 %s" % ", ".join(TEXTURE_DIRS))
		return
	_texture_index = clampi(_texture_index, 0, _texture_paths.size() - 1)
	_compose_free()
	_set_status("参考图：%s" % _texture_paths[_texture_index].get_file())

## 按选中的着色器重建右侧舞台与参数面板
## @side_effect
func _apply_free_shader() -> void:
	if _free_target == null:
		return
	if _shader_paths.is_empty():
		_set_status("没有找到着色器：检查 %s" % SHADER_DIR)
		return
	_shader_index = clampi(_shader_index, 0, _shader_paths.size() - 1)
	_compose_free()
	_left_caption.text = "参考图（原样）"
	_right_caption.text = "着色器（%s）" % _shader_paths[_shader_index].get_file()
	_title_label.text = "着色器实验室 · 自由对拍"
	_build_param_controls(_free_material.shader if _free_material != null else null)

## 参考图切换
## @internal
func _on_texture_selected(index_value: int) -> void:
	_texture_index = index_value
	_apply_free_texture()
	_update_free_status()

## 着色器切换
## @internal
func _on_shader_selected(index_value: int) -> void:
	_shader_index = index_value
	_apply_free_shader()
	_update_free_status()

## 按着色器声明重建参数控件
## @side_effect
func _build_param_controls(shader: Shader) -> void:
	for child: Node in _param_box.get_children():
		_param_box.remove_child(child)
		child.queue_free()
	if shader == null:
		_add_param_note("（着色器加载失败）")
		return
	var specs: Array[ParamSpec] = _parse_uniforms(shader.resource_path)
	if specs.is_empty():
		_add_param_note("该着色器没有可调参数")
		return
	for spec: ParamSpec in specs:
		_add_param_control(spec)

## 参数面板里的一行说明
## @internal
func _add_param_note(text: String) -> void:
	var note: Label = Label.new()
	note.text = text
	note.add_theme_font_size_override("font_size", 16)
	note.add_theme_color_override("font_color", Color(0.6, 0.66, 0.72))
	_param_box.add_child(note)

## 布尔参数的初始值：声明默认值；总开关（enable_* 且默认关）在实验室里默认打开，
## 否则挂了着色器也看不到任何变化——这正是「着色器没起效」的常见误判来源。
## @pure
func _initial_bool(spec: ParamSpec) -> bool:
	if bool(spec.default_value):
		return true
	return String(spec.key).begins_with("enable_")

## 按参数类型生成控件：bool 复选、float 滑杆、int 步进、color 取色
## @side_effect
func _add_param_control(spec: ParamSpec) -> void:
	if spec.type_name == "bool":
		var check: CheckBox = CheckBox.new()
		check.text = String(spec.key)
		var initial: bool = _initial_bool(spec)
		check.button_pressed = initial
		check.add_theme_font_size_override("font_size", 16)
		check.toggled.connect(_on_param_bool.bind(spec.key))
		_param_box.add_child(check)
		_apply_param(spec.key, initial)
		return
	if spec.type_name == "float":
		_add_float_slider(spec)
		return
	if spec.type_name == "int":
		var spin: SpinBox = SpinBox.new()
		spin.min_value = spec.min_value
		spin.max_value = spec.max_value
		spin.step = 1.0
		spin.value = float(spec.default_value)
		spin.value_changed.connect(_on_param_float.bind(spec.key))
		_param_box.add_child(spin)
		_apply_param(spec.key, int(spec.default_value))
		return
	if spec.type_name == "color":
		var picker: ColorPickerButton = ColorPickerButton.new()
		picker.color = spec.default_value if spec.default_value is Color else Color.WHITE
		picker.custom_minimum_size = Vector2(160.0, 32.0)
		picker.color_changed.connect(_on_param_color.bind(spec.key))
		_param_box.add_child(picker)
		_apply_param(spec.key, picker.color)
		return
	_add_param_note("（%s 的参数 %s 暂不支持控件）" % [spec.type_name, String(spec.key)])

## 滑杆行：名称 + 滑杆 + 当前值
## @side_effect
func _add_float_slider(spec: ParamSpec) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label: Label = Label.new()
	label.text = String(spec.key)
	label.custom_minimum_size = Vector2(240.0, 0.0)
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = spec.min_value
	slider.max_value = spec.max_value
	slider.step = maxf((spec.max_value - spec.min_value) / 200.0, 0.001)
	# 不给伸展与最小宽度时，HBox 只按控件最小尺寸分配，滑杆会被压成一条缝
	slider.custom_minimum_size = Vector2(280.0, 0.0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label: Label = Label.new()
	value_label.text = "%.3f" % float(spec.default_value)
	value_label.custom_minimum_size = Vector2(90.0, 0.0)
	value_label.add_theme_font_size_override("font_size", 16)
	row.add_child(value_label)
	slider.value_changed.connect(_on_param_slider.bind(spec.key, value_label))
	_param_box.add_child(row)
	_apply_param(spec.key, float(spec.default_value))

## 写一个参数到右侧舞台并刷新状态
## @side_effect
func _apply_param(key: StringName, value: Variant) -> void:
	if _free_target == null:
		return
	_free_target.set_param(key, value)

## 参数回调：bool
## @internal
func _on_param_bool(value: bool, key: StringName) -> void:
	_apply_param(key, value)
	_update_free_status()

## 参数回调：float / int
## @internal
func _on_param_float(value: float, key: StringName) -> void:
	_apply_param(key, value)
	_update_free_status()

## 参数回调：滑杆（同时刷新数值标签）
## @internal
func _on_param_slider(value: float, key: StringName, value_label: Label) -> void:
	value_label.text = "%.3f" % value
	_apply_param(key, value)
	_update_free_status()

## 参数回调：颜色
## @internal
func _on_param_color(value: Color, key: StringName) -> void:
	_apply_param(key, value)
	_update_free_status()

## 状态栏：着色器、参考图与当前生效参数
## @side_effect
func _update_free_status() -> void:
	if _free_target == null or _shader_paths.is_empty():
		return
	var names: PackedStringArray = PackedStringArray()
	for spec: ParamSpec in _parse_uniforms(_shader_paths[_shader_index]):
		names.append(String(spec.key))
	var parts: PackedStringArray = PackedStringArray()
	for name: String in names:
		var value: Variant = _free_target.param_value(StringName(name))
		parts.append("%s=%s" % [name, _format_value(value) if value != null else "默认"])
	_set_status("%s  |  %s" % [_shader_paths[_shader_index].get_file(), ", ".join(parts)])

#==扫描==
## 扫描着色器候选
## @external
func _scan_shaders() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	_collect_files(SHADER_DIR, ".gdshader", out)
	out.sort()
	return out

## 扫描参考图候选
## @external
func _scan_textures() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for dir: String in TEXTURE_DIRS:
		_collect_files(dir, ".png", out)
	out.sort()
	return out

## 递归收集某后缀的文件
## @external
func _collect_files(dir_path: String, suffix: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for entry: String in dir.get_files():
		if entry.ends_with(suffix):
			out.append(dir_path.path_join(entry))
	for sub: String in dir.get_directories():
		if sub == "." or sub == "..":
			continue
		_collect_files(dir_path.path_join(sub), suffix, out)

#==参数解析==
## 从着色器源（含 #include 的 .gdshaderinc）解析出可调参数
## @external
func _parse_uniforms(shader_path: String) -> Array[ParamSpec]:
	var specs: Array[ParamSpec] = []
	if shader_path.is_empty():
		return specs
	var pattern: RegEx = RegEx.create_from_string(UNIFORM_PATTERN)
	var range_pattern: RegEx = RegEx.create_from_string(RANGE_PATTERN)
	for line: String in _read_shader_lines(shader_path):
		var hit: RegExMatch = pattern.search(line)
		if hit == null:
			continue
		var type_name: String = hit.get_string(1)
		var key: StringName = StringName(hit.get_string(2))
		var hint: String = hit.get_string(3)
		var raw_default: String = hit.get_string(4).strip_edges()
		var min_value: float = 0.0
		var max_value: float = 1.0
		if not hint.is_empty():
			var range_hit: RegExMatch = range_pattern.search(hint)
			if range_hit != null:
				min_value = float(range_hit.get_string(1))
				max_value = float(range_hit.get_string(2))
		specs.append(ParamSpec.new(key, type_name, min_value, max_value, _parse_default(type_name, raw_default, min_value, max_value)))
	return specs

## 解析默认值字面量
## @pure
func _parse_default(type_name: String, raw: String, min_value: float, max_value: float) -> Variant:
	if type_name == "bool":
		return raw == "true"
	if type_name == "int":
		return int(raw.to_int())
	if type_name == "float":
		return raw.to_float() if not raw.is_empty() else min_value
	if type_name == "color":
		return Color.WHITE
	return null

## 读着色器源行，并把 #include 的文件内容一并展开
## @external
func _read_shader_lines(shader_path: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var include_pattern: RegEx = RegEx.create_from_string(INCLUDE_PATTERN)
	for line: String in _read_text_lines(shader_path):
		var hit: RegExMatch = include_pattern.search(line)
		if hit == null:
			lines.append(line)
			continue
		var include_path: String = hit.get_string(1)
		for include_line: String in _read_text_lines(include_path):
			lines.append(include_line)
	return lines

## 读文本文件的各行；读不到返回空
## @external
func _read_text_lines(path: String) -> PackedStringArray:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedStringArray()
	var text: String = file.get_as_text()
	file.close()
	return text.split("\n")

#==呈现工具==
## @pure
func _format_value(value: Variant) -> String:
	if value is float:
		return "%.3f" % value
	if value is int:
		return "%d" % value
	if value is bool:
		return "true" if value else "false"
	if value is Color:
		return "#" + (value as Color).to_html(false)
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
	display.position = Vector2.ZERO
	display.size = PANEL_SIZE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE

## @internal
func _set_status(text: String) -> void:
	_status_label.text = text
