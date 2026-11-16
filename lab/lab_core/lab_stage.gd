## 通用实验室舞台：用例来自全局配置表，交互与无头共用同一份。
## 引导（键位、实参、上报、退出码）由 LabShell 承担，本类只负责用例列表、舞台与读数。
class_name LabStage
extends LabShell
## 用例列表组件：交互与着色器实验室共用同一份按钮列呈现
const LabCaseListScript := preload("res://lab/lab_core/lab_case_list.gd")

#==vars==
## 已加载用例
var _cases: Array[LabCase] = []
## 执行器
var _runner: LabRunner
## 舞台上待居中的用例实例
var _center_target: Control = null
## 用例列表按钮容器
var _case_box: LabCaseListScript
## 舞台容器（用例场景实例挂在这里）
var _stage_root: Control
## 读数区
var _readout: RichTextLabel
## 当前选中的用例下标
var _current: int = 0
## 是否启用角色框剪裁（按可拉伸的剪裁框裁剪）
var _clip_mode: bool = false
## 舞台缩放倍率（滚轮调整，Ctrl+滚轮复位）
var _zoom: float = 1.0
## 剪裁框：用例实例挂在它里面，按它自己的矩形裁剪
var _clip_box: Control
## 剪裁框描边
var _frame_border: ReferenceRect
## 四角拉伸把手
var _handles: Array[Control] = []
## 框内拖移层（不吃滚轮，滚轮继续上抛给舞台）
var _move_grip: Control
## 剪裁框是否被手动调整过（调整过就不再随舞台尺寸自动居中）
var _box_moved: bool = false
## 正在拖动的把手下标；-1 表示未拖动，-2 表示正在拖移整框
var _drag_handle: int = -1
## 拖动起点（全局坐标）与起点尺寸/位置
var _drag_origin: Vector2 = Vector2.ZERO
var _drag_rect: Rect2 = Rect2()
## 剪裁模式复选与缩放读数
var _clip_check: CheckBox
var _zoom_label: Label

#==hooks==
## 就绪：建执行器与界面，读用例表
## @override
func _lab_boot() -> void:
	_runner = LabRunner.new(self)
	_build_ui()
	_load_cases()

## 重载后重建：重读用例表
## @override
func _lab_reload() -> void:
	_load_cases()

## 键盘：1-9 与 0（第 10 条）选用例并执行，上下键移动，回车执行
## @override
func _lab_input(key: InputEventKey) -> void:
	var index: int = -1
	if key.keycode >= KEY_1 and key.keycode <= KEY_9:
		index = key.keycode - KEY_1
	elif key.keycode == KEY_0:
		index = 9
	if index >= 0 and index < _cases.size():
		_current = index
		_run_current()
		return
	if key.keycode == KEY_DOWN:
		_current = (_current + 1) % maxi(_cases.size(), 1)
		return
	if key.keycode == KEY_UP:
		_current = (_current - 1 + _cases.size()) % maxi(_cases.size(), 1)
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		_run_current()

## 上报同时落进读数区
## @override
func _on_reported(text: String) -> void:
	if _readout == null:
		return
	_readout.text = (_readout.text + "\n" + text) if not _readout.text.is_empty() else text

## 用例表里的全部标识
## @override
func case_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for case: LabCase in _cases:
		ids.append(case.case_id)
	return ids

## 执行一条用例；未知标识按失败回送
## @override
func run_case(case_id: StringName) -> Dictionary[StringName, Variant]:
	for case: LabCase in _cases:
		if case.case_id == case_id:
			return await _runner.run_case(lab_id, case)
	var lines: PackedStringArray = PackedStringArray(["用例未加载：%s" % case_id])
	return { &"tag": "%s/%s" % [lab_id, case_id], &"ok": false, &"failures": 1, &"lines": lines }

#==public==
## 用例场景实例的挂载容器（LabRunner 使用）：剪裁框内部，裁剪即按框生效
## @pure
func get_case_container() -> Control:
	return _clip_box

#==internal==
## 读用例表并重建列表与表头
## @internal
func _load_cases() -> void:
	_cases = LabSpec.load_cases(lab_scope, lab_table, lab_id)
	_fill_case_list()
	_report_header()

## 交互模式：跑当前选中的用例
## @internal
func _run_current() -> void:
	if _cases.is_empty():
		report_line("没有用例：检查 %s/%s.cfg 的 [case:%s:*] 段" % [lab_scope, lab_table, lab_id])
		return
	var result: Dictionary[StringName, Variant] = await run_case(_cases[_current].case_id)
	report_result(result)

## 打印表头与用例清单（GUI 与无头都打，便于 AI 发现用例标识）
## @internal
func _report_header() -> void:
	report_line("%s  lab=%s scope=%s table=%s cases=%d" % [lab_title, lab_id, lab_scope, lab_table, _cases.size()])
	for index: int in _cases.size():
		report_line("  [%d] %s -> %s" % [index + 1, _cases[index].case_id, _cases[index].scene_path])

## 建界面：标题、用例列表、舞台、读数
## @internal
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var title: Label = Label.new()
	title.text = lab_title
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	_case_box = LabCaseListScript.new()
	_case_box.custom_minimum_size = Vector2(260.0, 0.0)
	body.add_child(_case_box)
	_stage_root = Control.new()
	_stage_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage_root.clip_contents = false
	_stage_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_stage_root.gui_input.connect(_on_stage_gui_input)
	_stage_root.resized.connect(_center_case)
	_stage_root.resized.connect(_on_stage_resized)
	body.add_child(_stage_root)
	_build_clip_box()
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	_clip_check = CheckBox.new()
	_clip_check.text = "角色框剪裁"
	_clip_check.toggled.connect(_on_clip_toggled)
	bar.add_child(_clip_check)
	_zoom_label = Label.new()
	_zoom_label.text = _zoom_text()
	bar.add_child(_zoom_label)
	root.add_child(bar)
	_readout = RichTextLabel.new()
	_readout.bbcode_enabled = false
	_readout.custom_minimum_size = Vector2(0.0, 160.0)
	_readout.add_theme_font_size_override("normal_font_size", 16)
	root.add_child(_readout)

## 用例按钮：点击即执行
## @internal
func _fill_case_list() -> void:
	var labels: PackedStringArray = PackedStringArray()
	for index: int in _cases.size():
		labels.append("%d. %s" % [index + 1, _cases[index].case_id])
	_case_box.fill(labels, _on_case_button)
	_case_box.mark_selected(_current)

## 按钮回调
## @internal
func _on_case_button(index: int) -> void:
	_current = index
	_run_current()

## 把用例实例摆到舞台中央；执行器在实例入树后调用
## @hook
func place_case_instance(instance: Node) -> void:
	_center_target = instance as Control
	_apply_zoom()
	_apply_clip_mode()
	if is_instance_valid(_center_target) and not _center_target.resized.is_connected(_center_case):
		_center_target.resized.connect(_center_case)
	_center_case()

## 重新计算居中位置；舞台尺寸变化与实例更换时都要走这里
## @internal
func _center_case() -> void:
	if not is_instance_valid(_center_target):
		return
	# 支点属于场景自身语义，不能改：角色容器用它把旋转中心放在脚底（倒地才是以脚为轴）。
	# 缩放绕 pivot 生效，所以按「视觉中心落在框中心」反解位置：
	# 视觉中心 = position + pivot*(1-s) + size*s/2。
	var s: float = _zoom
	var pivot: Vector2 = _center_target.pivot_offset
	var center: Vector2 = _clip_box.size * 0.5
	_center_target.position = center - _center_target.size * s * 0.5 - pivot * (1.0 - s)
	_sync_frame()

#==角色框与缩放==
## 缩放读数文案
## @pure
func _zoom_text() -> String:
	return "缩放 %.2fx（滚轮缩放，Ctrl+滚轮复位）" % _zoom

## 勾选角色框剪裁：把用例实例裁到自身矩形，并显示框线
## @side_effect
func _on_clip_toggled(pressed: bool) -> void:
	_clip_mode = pressed
	_apply_clip_mode()

## 舞台上的滚轮：缩放用例实例；按住 Ctrl 复位到 1.00x
## @side_effect
func _on_stage_gui_input(event: InputEvent) -> void:
	var wheel: InputEventMouseButton = event as InputEventMouseButton
	if wheel == null or not wheel.pressed:
		return
	if wheel.button_index != MOUSE_BUTTON_WHEEL_UP and wheel.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return
	if wheel.is_command_or_control_pressed():
		_set_zoom(1.0)
		return
	var step: float = 1.1 if wheel.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1
	_set_zoom(_zoom * step)
	_stage_root.accept_event()

## 设定并应用缩放倍率（钳位到 0.25–6.0）
## @side_effect
func _set_zoom(value: float) -> void:
	_zoom = clampf(value, 0.25, 6.0)
	_apply_zoom()

## 把缩放写进用例实例并重新居中
## @side_effect
func _apply_zoom() -> void:
	if _zoom_label != null:
		_zoom_label.text = _zoom_text()
	if is_instance_valid(_center_target):
		_center_target.scale = Vector2(_zoom, _zoom)
	_center_case()

## 把剪裁状态与框线同步到当前实例
## @side_effect
func _apply_clip_mode() -> void:
	if _clip_box == null:
		return
	# 裁剪由剪裁框承担：实例始终挂在框内，开/关只影响框是否可见可拖
	_clip_box.clip_contents = _clip_mode
	_sync_frame()
	_center_case()

## 建剪裁框、描边、四角把手与框内拖移层
## @side_effect
func _build_clip_box() -> void:
	_clip_box = Control.new()
	_clip_box.name = "ClipBox"
	_clip_box.size = Vector2(220.0, 420.0)
	_clip_box.clip_contents = true
	# 框本身不吃鼠标：滚轮要能上抛给舞台做缩放
	_clip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_root.add_child(_clip_box)
	_center_clip_box()

	_frame_border = ReferenceRect.new()
	_frame_border.editor_only = false
	_frame_border.border_color = Color(0.0, 0.9, 0.87, 0.9)
	_frame_border.border_width = 2.0
	_frame_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_root.add_child(_frame_border)

	_move_grip = Control.new()
	_move_grip.name = "MoveGrip"
	_move_grip.mouse_filter = Control.MOUSE_FILTER_PASS
	_move_grip.gui_input.connect(_on_grip_input)
	_stage_root.add_child(_move_grip)

	for corner: int in 4:
		var handle: Control = ColorRect.new()
		handle.name = "Handle%d" % corner
		(handle as ColorRect).color = Color(0.0, 0.9, 0.87, 0.95)
		handle.mouse_filter = Control.MOUSE_FILTER_STOP
		handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE if corner % 3 == 0 else Control.CURSOR_BDIAGSIZE
		handle.size = Vector2(14.0, 14.0)
		handle.gui_input.connect(_on_handle_input.bind(corner))
		_stage_root.add_child(handle)
		_handles.append(handle)
	_sync_frame()

## 剪裁框默认摆到舞台中央
## @side_effect
func _center_clip_box() -> void:
	_clip_box.position = (_stage_root.size - _clip_box.size) * 0.5

## 把描边、把手、拖移层贴到剪裁框上
## @side_effect
func _sync_frame() -> void:
	if _frame_border == null or _clip_box == null:
		return
	_frame_border.position = _clip_box.position
	_frame_border.size = _clip_box.size
	_frame_border.visible = _clip_mode
	_move_grip.position = _clip_box.position
	_move_grip.size = _clip_box.size
	_move_grip.mouse_filter = Control.MOUSE_FILTER_PASS if _clip_mode else Control.MOUSE_FILTER_IGNORE
	var offset: Vector2 = Vector2(7.0, 7.0)
	var corners: Array[Vector2] = [
		_clip_box.position - offset,
		_clip_box.position + Vector2(_clip_box.size.x - offset.x, -offset.y),
		_clip_box.position + Vector2(-offset.x, _clip_box.size.y - offset.y),
		_clip_box.position + _clip_box.size - offset,
	]
	for index: int in _handles.size():
		var handle: Control = _handles[index]
		handle.position = corners[index]
		handle.visible = _clip_mode

## 舞台尺寸变化：框还没被手动调整过时保持居中（首次布局时舞台尺寸为 0）
## @side_effect
func _on_stage_resized() -> void:
	if _box_moved or _clip_box == null:
		return
	_center_clip_box()
	_sync_frame()

## 按新矩形重设剪裁框（拖动与判据共用），最小 40×40
## @side_effect
func set_clip_rect(rect: Rect2) -> void:
	_box_moved = true
	var min_size: float = 40.0
	var size: Vector2 = Vector2(maxf(rect.size.x, min_size), maxf(rect.size.y, min_size))
	_clip_box.size = size
	_clip_box.position = rect.position
	_center_case()
	_sync_frame()

## 框内拖移：整体移动剪裁框
## @side_effect
func _on_grip_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_drag_handle = -2
			_drag_origin = _stage_root.get_global_mouse_position()
			_drag_rect = Rect2(_clip_box.position, _clip_box.size)
		else:
			_drag_handle = -1
		return
	if motion == null or _drag_handle != -2:
		return
	var delta: Vector2 = _stage_root.get_global_mouse_position() - _drag_origin
	set_clip_rect(Rect2(_drag_rect.position + delta, _drag_rect.size))

## 四角拉伸：按对角反向的固定点缩放剪裁框
## @side_effect
func _on_handle_input(event: InputEvent, corner: int) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_drag_handle = corner
			_drag_origin = _stage_root.get_global_mouse_position()
			_drag_rect = Rect2(_clip_box.position, _clip_box.size)
		else:
			_drag_handle = -1
		return
	if motion == null or _drag_handle != corner:
		return
	var delta: Vector2 = _stage_root.get_global_mouse_position() - _drag_origin
	var left: float = _drag_rect.position.x
	var top: float = _drag_rect.position.y
	var right: float = _drag_rect.position.x + _drag_rect.size.x
	var bottom: float = _drag_rect.position.y + _drag_rect.size.y
	# 左上角拖左上、右下角拖右下，另两角各自反向
	if corner == 0:
		left += delta.x
		top += delta.y
	elif corner == 1:
		right += delta.x
		top += delta.y
	elif corner == 2:
		left += delta.x
		bottom += delta.y
	else:
		right += delta.x
		bottom += delta.y
	set_clip_rect(Rect2(Vector2(left, top), Vector2(right - left, bottom - top)))
