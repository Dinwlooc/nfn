## 通用着色器实验室：左边参考图、右边同一张图穿着色器，可切换参考图、切换着色器、实时调参；
## 另保留「用例对拍」模式：按数据定义的用例并排显示真实场景的基线 / 当前。
## 每条用例声明场景、显示子树、目标 CanvasItem、着色器文件名、基线/当前参数与要展示的参数名。
## 引导（键位、实参、上报、退出码）由 LabShell 承担，本类只负责呈现。
extends LabShell
## 用例列表组件：与交互实验室共用同一份按钮列呈现
const LabCaseListScript := preload("res://lab/lab_core/lab_case_list.gd")
const PANEL_SIZE: Vector2 = Vector2(760.0, 427.5)
const PANEL_Y: float = 96.0
const LEFT_X: float = 30.0
const RIGHT_X: float = 810.0
## 着色器候选目录（递归扫描 .gdshader）
const SHADER_DIR: String = "res://resource/default/shader/gdshader/"
## 参考图候选目录（递归扫描已导入的位图）
const TEXTURE_DIRS: Array[String] = ["res://resource/default/assets/"]

## 着色器声明行的解析式：捕获类型名、变量名、hint 段与默认值
const UNIFORM_PATTERN: String = "^\\s*(?:instance\\s+)?uniform\\s+([A-Za-z_][A-Za-z0-9_]*)\\s+([A-Za-z_][A-Za-z0-9_]*)\\s*(?::\\s*([^=]*))?(?:=\\s*([^;]*))?;"
## hint_range 的上下界
const RANGE_PATTERN: String = "hint_range\\(\\s*(-?[0-9.]+)\\s*,\\s*(-?[0-9.]+)"
## 着色器源里的 include 行（uniform 可能写在 .gdshaderinc 里）
const INCLUDE_PATTERN: String = "#include\\s+\"([^\"]+)\""

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

var _cases: Array[ShaderCase] = []
var _case_index: int = 0
var _pair_root: Control
var _title_label: Label
var _left_caption: Label
var _right_caption: Label
## 用例选择列表
var _case_list: LabCaseListScript
var _status_label: Label
var _help_label: Label
## 当前是否处于自由对拍模式
var _free_mode: bool = true
## 模式切换按钮
var _case_mode_button: Button
var _free_mode_button: Button
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
## 自由对拍的左参考图与右着色器展示
var _free_ref: TextureRect
var _free_target: TextureRect
var _free_material: ShaderMaterial

## 就绪：建用例表与静态界面，先进自由对拍
## @override
func _lab_boot() -> void:
	if lab_id.is_empty():
		lab_id = &"shader"
	_build_cases()
	_build_static_ui()
	_set_mode(true)

## 重载后重建当前模式
## @override
func _lab_reload() -> void:
	if _free_mode:
		_build_free_pair()
		return
	_build_pair(_case_index)

## 键盘：1-N 选用例（仅用例模式），M 切换模式
## @override
func _lab_input(key: InputEventKey) -> void:
	if key.keycode == KEY_M:
		_set_mode(not _free_mode)
		return
	if _free_mode:
		return
	var case_number: int = key.keycode - KEY_1
	if case_number < 0 or case_number >= _cases.size():
		return
	_select_case(case_number)

## 用例标识取序号；用例身份仍留在本文件的 _build_cases
## @override
func case_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for index: int in _cases.size():
		ids.append(StringName(str(index + 1)))
	return ids

## 无断言：重建成功即 PASS，观感由人眼判断
## @override
func run_case(case_id: StringName) -> Dictionary[StringName, Variant]:
	var index: int = int(String(case_id)) - 1
	if index < 0 or index >= _cases.size():
		var unknown: PackedStringArray = PackedStringArray(["未知用例：%s" % case_id])
		return { &"tag": "%s/%s" % [lab_id, case_id], &"ok": false, &"failures": 1, &"lines": unknown }
	_set_mode(false)
	_case_index = index
	var built: bool = _build_pair(index)
	if _case_list != null:
		_case_list.mark_selected(index)
	var lines: PackedStringArray = PackedStringArray()
	if not built:
		lines.append("重建失败：%s" % _cases[index].label)
	return { &"tag": "%s/%s" % [lab_id, case_id], &"ok": built, &"failures": 0 if built else 1, &"lines": lines }

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

#==界面==
## 建静态界面：标题、双栏、模式切换、选择器、参数面板、状态与用例列表
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
	add_child(divider)

	_build_mode_row()
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
	add_child(_help_label)

	_case_list = LabCaseListScript.new()
	_case_list.position = Vector2(RIGHT_X, 676.0)
	_case_list.custom_minimum_size = Vector2(760.0, 0.0)
	add_child(_case_list)
	_fill_case_list()

## 模式切换按钮
## @internal
func _build_mode_row() -> void:
	_case_mode_button = Button.new()
	_case_mode_button.text = "① 用例对拍"
	_case_mode_button.position = Vector2(LEFT_X, 534.0)
	_case_mode_button.size = Vector2(190.0, 34.0)
	_case_mode_button.pressed.connect(_on_mode_pressed.bind(false))
	add_child(_case_mode_button)
	_free_mode_button = Button.new()
	_free_mode_button.text = "② 自由对拍"
	_free_mode_button.position = Vector2(LEFT_X + 200.0, 534.0)
	_free_mode_button.size = Vector2(190.0, 34.0)
	_free_mode_button.pressed.connect(_on_mode_pressed.bind(true))
	add_child(_free_mode_button)

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
	add_child(label)
	return label

## 重建用例选择列表：标签用序号与标题，点选即切换
## @internal
func _fill_case_list() -> void:
	var labels: PackedStringArray = PackedStringArray()
	for index: int in _cases.size():
		labels.append("%d. %s" % [index + 1, _cases[index].label])
	_case_list.fill(labels, _select_case)
	_case_list.mark_selected(_case_index)

## 切到某条用例：重建并刷新列表高亮
## @internal
func _select_case(index: int) -> void:
	if index < 0 or index >= _cases.size():
		return
	_set_mode(false)
	_case_index = index
	_build_pair(_case_index)
	if _case_list != null:
		_case_list.mark_selected(_case_index)

## 模式按钮回调
## @internal
func _on_mode_pressed(free_mode: bool) -> void:
	_set_mode(free_mode)

## 切换模式：自由对拍显示选择器与参数面板，用例对拍显示用例列表
## @side_effect
func _set_mode(free_mode: bool) -> void:
	_free_mode = free_mode
	_texture_option.visible = free_mode
	_shader_option.visible = free_mode
	_param_scroll.visible = free_mode
	_case_list.visible = not free_mode
	if free_mode:
		_build_free_pair()
	else:
		_build_pair(_case_index)
	_update_help()

## 刷新帮助行
## @side_effect
func _update_help() -> void:
	var base: String = "M 切换模式    R 重新加载    Esc 返回主菜单（独立运行时退出）"
	if _free_mode:
		_help_label.text = "选参考图 / 着色器 → 下方调参即时生效    " + base
		return
	_help_label.text = "1-%d 或点选用例列表    " % _cases.size() + base

#==自由对拍==
## 建自由对拍：左参考图原样、右同图穿着色器并挂选中的参数
## @internal
func _build_free_pair() -> void:
	if _pair_root != null:
		_pair_root.queue_free()
		_pair_root = null
	_pair_root = Control.new()
	# 容器本身不吃鼠标：它铺满全屏且后于控件创建，STOP 会盖住下拉与参数面板
	_pair_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pair_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_pair_root)

	_free_ref = TextureRect.new()
	_free_ref.size = PANEL_SIZE
	_free_ref.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_free_ref.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	_free_target = TextureRect.new()
	_free_target.size = PANEL_SIZE
	_free_target.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_free_target.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_free_material = ShaderMaterial.new()
	_free_target.material = _free_material

	_attach_panel(_free_ref, Vector2(LEFT_X, PANEL_Y))
	_attach_panel(_free_target, Vector2(RIGHT_X, PANEL_Y))

	_apply_free_texture()
	_apply_free_shader()

## 把选中的参考图贴到两侧（左侧原图，右侧同图供着色器处理）
## @side_effect
func _apply_free_texture() -> void:
	if _free_ref == null or _free_target == null:
		return
	if _texture_paths.is_empty():
		_set_status("没有找到参考图：检查 %s" % ", ".join(TEXTURE_DIRS))
		return
	_texture_index = clampi(_texture_index, 0, _texture_paths.size() - 1)
	var texture: Texture2D = load(_texture_paths[_texture_index]) as Texture2D
	_free_ref.texture = texture
	_free_target.texture = texture
	_set_status("参考图：%s" % _texture_paths[_texture_index].get_file())

## 把选中的着色器挂到右侧并重建参数面板
## @side_effect
func _apply_free_shader() -> void:
	if _free_target == null:
		return
	if _shader_paths.is_empty():
		_set_status("没有找到着色器：检查 %s" % SHADER_DIR)
		return
	_shader_index = clampi(_shader_index, 0, _shader_paths.size() - 1)
	var shader: Shader = load(_shader_paths[_shader_index]) as Shader
	_free_material.shader = shader
	# 重新挂一次材质：换 shader 后确保 TextureRect 用的就是这份材质
	_free_target.material = _free_material
	_left_caption.text = "参考图（原样）"
	_right_caption.text = "着色器（%s）" % _shader_paths[_shader_index].get_file()
	_title_label.text = "着色器实验室 · 自由对拍"
	_build_param_controls(shader)

## 参考图切换
## @internal
func _on_texture_selected(index: int) -> void:
	_texture_index = index
	_apply_free_texture()
	_update_free_status()

## 着色器切换
## @internal
func _on_shader_selected(index: int) -> void:
	_shader_index = index
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
	slider.value = float(spec.default_value)
	slider.custom_minimum_size = Vector2(360.0, 24.0)
	row.add_child(slider)
	var value_label: Label = Label.new()
	value_label.text = "%.3f" % float(spec.default_value)
	value_label.custom_minimum_size = Vector2(90.0, 0.0)
	value_label.add_theme_font_size_override("font_size", 16)
	row.add_child(value_label)
	slider.value_changed.connect(_on_param_slider.bind(spec.key, value_label))
	_param_box.add_child(row)
	_apply_param(spec.key, float(spec.default_value))

## 写一个参数到右侧材质并刷新状态
## @side_effect
func _apply_param(key: StringName, value: Variant) -> void:
	if _free_target == null:
		return
	_free_target.set_instance_shader_parameter(key, value)

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
		var key: StringName = StringName(name)
		var value: Variant = _free_target.get_instance_shader_parameter(key)
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

#==用例对拍==
## 重建并返回是否成功；失败原因进状态栏
## @internal
func _build_pair(index: int) -> bool:
	if _pair_root != null:
		_pair_root.queue_free()
		_pair_root = null
	var case_data: ShaderCase = _cases[index]
	var packed: PackedScene = load(case_data.scene_path) as PackedScene
	if packed == null:
		_set_status("无法加载场景：%s" % case_data.scene_path)
		return false
	var baseline: Control = _extract_display(packed, case_data.display_selector, case_data.display_scale)
	var current: Control = _extract_display(packed, case_data.display_selector, case_data.display_scale)
	if baseline == null or current == null:
		if baseline != null:
			baseline.queue_free()
		if current != null:
			current.queue_free()
		_set_status("无法提取显示子树：%s" % case_data.display_selector)
		return false

	_pair_root = Control.new()
	# 容器本身不吃鼠标：它铺满全屏且后于控件创建，STOP 会盖住下拉与参数面板
	_pair_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pair_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pair_root)
	_attach_panel(baseline, Vector2(LEFT_X, PANEL_Y))
	_attach_panel(current, Vector2(RIGHT_X, PANEL_Y))

	var baseline_target: CanvasItem = _find_target(baseline, case_data)
	var current_target: CanvasItem = _find_target(current, case_data)
	if baseline_target == null or current_target == null:
		_set_status("目标节点或着色器不匹配：%s" % case_data.shader_file)
		return false
	_apply_params(baseline_target, case_data.baseline_params)
	_apply_params(current_target, case_data.current_params)
	_title_label.text = "着色器实验室 · %s" % case_data.label
	_left_caption.text = "基线（%s）" % _format_overrides(case_data.baseline_params)
	_right_caption.text = "当前（%s）" % _format_overrides(case_data.current_params)
	_status_label.text = "%s  |  %s" % [
		case_data.shader_file,
		_format_readout(current_target, case_data.readout_params),
	]
	return true

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
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE

## @internal
func _set_status(text: String) -> void:
	_status_label.text = text
