## 角色表现（CharacterFace）实验室：一个场景覆盖角色受击、倒地、魔法受击与边界数据。
## Face 是项目术语：表现层封装交互接口的根控件类；本实验室测的是其中的 CharacterFace。
## 预设全部来自配置表，交互与无头共用同一份；本脚本只声明界面与处理器。
extends FaceLab

## 预设列表脚本：新类名未进全局类缓存，故以预加载常量引用；重扫登记后可改回按类名静态调用
const PresetListScript: Script = preload("res://lab/lab_core/LabPresetList.gd")

#==字段==
## 预设列表控件
var preset_box: VBoxContainer = null
## 舞台容器（预设实例挂在剪裁框内）
var stage_root: Control = null
## 读数区
var readout: RichTextLabel = null
## 舞台上待居中的实例
var center_target: Control = null
## 当前选中预设下标
var current: int = 0
## 舞台缩放倍率
var zoom: float = 1.0
## 是否启用角色框剪裁
var clip_mode: bool = false
## 剪裁框
var clip_box: Control = null
## 剪裁框描边
var frame_border: ReferenceRect = null
## 四角拉伸把手
var handles: Array[Control] = []
## 框内拖移层
var move_grip: Control = null
## 剪裁框是否被手动调整过
var box_moved: bool = false
## 正在拖动的把手下标；-2 表示拖移整框
var drag_handle: int = -1
## 拖动起点
var drag_origin: Vector2 = Vector2.ZERO
## 拖动起点矩形
var drag_rect: Rect2 = Rect2()
## 剪裁模式复选
var clip_check: CheckBox = null
## 缩放读数
var zoom_label: Label = null

#==钩子==
## 处理器：角色实验室只认 CharacterFace 的测试接口
## @override
func _create_handler() -> LabHandler:
	return CharacterFaceLabHandler.new(data)

## 预设实例挂在剪裁框内：裁剪按框生效，位置也相对框计算
## @override
func _preset_container() -> Node:
	return clip_box if clip_box != null else self

## 实例入树后挂到舞台上：缩放、剪裁、居中
## @override
func _attach_instance(node: Node) -> void:
	center_target = node as Control
	_apply_zoom()
	_apply_clip_mode()
	if is_instance_valid(center_target) and not center_target.resized.is_connected(_center_case):
		center_target.resized.connect(_center_case)
	_center_case()

## 上报同时落进读数区
## @override
func _on_reported(text: String) -> void:
	if readout == null:
		return
	readout.text = (readout.text + "\n" + text) if not readout.text.is_empty() else text

## 建界面：标题、预设列表、舞台、读数与剪裁框
## @override
func _build_gui() -> void:
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
	preset_box = PresetListScript.new()
	preset_box.custom_minimum_size = Vector2(260.0, 0.0)
	body.add_child(preset_box)
	stage_root = Control.new()
	stage_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_root.clip_contents = false
	stage_root.mouse_filter = Control.MOUSE_FILTER_STOP
	stage_root.gui_input.connect(_on_stage_gui_input)
	stage_root.resized.connect(_on_stage_resized)
	body.add_child(stage_root)
	_build_clip_box()
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	clip_check = CheckBox.new()
	clip_check.text = "角色框剪裁"
	clip_check.toggled.connect(_on_clip_toggled)
	bar.add_child(clip_check)
	zoom_label = Label.new()
	zoom_label.text = _zoom_text()
	bar.add_child(zoom_label)
	root.add_child(bar)
	readout = RichTextLabel.new()
	readout.bbcode_enabled = false
	readout.custom_minimum_size = Vector2(0.0, 160.0)
	readout.add_theme_font_size_override("normal_font_size", 16)
	root.add_child(readout)
	_fill_preset_list()

#==界面==
## 重建预设按钮列
## @internal
func _fill_preset_list() -> void:
	if preset_box == null:
		return
	var labels: PackedStringArray = PackedStringArray()
	for i: int in presets.size():
		labels.append("%d. %s" % [i + 1, presets[i]])
	preset_box.call("fill", labels, _on_preset_button)
	preset_box.call("mark_selected", current)

## 按钮回调
## @internal
func _on_preset_button(index: int) -> void:
	current = index
	start_preset(presets[index])

## 重新计算居中位置；支点属于场景自身语义，不能改
## @internal
func _center_case() -> void:
	if not is_instance_valid(center_target) or clip_box == null:
		return
	var s: float = zoom
	var pivot: Vector2 = center_target.pivot_offset
	var center: Vector2 = clip_box.size * 0.5
	center_target.position = center - center_target.size * s * 0.5 - pivot * (1.0 - s)
	_sync_frame()

## 缩放读数文案
## @internal
func _zoom_text() -> String:
	return "缩放 %.2fx（滚轮缩放，Ctrl+滚轮复位）" % zoom

## 设定并应用缩放倍率（钳位 0.25–6.0）
## @internal
func _set_zoom(value: float) -> void:
	zoom = clampf(value, 0.25, 6.0)
	_apply_zoom()

## 把缩放写进实例并重新居中
## @internal
func _apply_zoom() -> void:
	if zoom_label != null:
		zoom_label.text = _zoom_text()
	if is_instance_valid(center_target):
		center_target.scale = Vector2(zoom, zoom)
	_center_case()

## 把剪裁状态与框线同步到当前实例
## @internal
func _apply_clip_mode() -> void:
	if clip_box == null:
		return
	clip_box.clip_contents = clip_mode
	_sync_frame()
	_center_case()

## 舞台滚轮：缩放实例；按住 Ctrl 复位
## @internal
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
	_set_zoom(zoom * step)
	stage_root.accept_event()

## 勾选角色框剪裁
## @internal
func _on_clip_toggled(pressed: bool) -> void:
	clip_mode = pressed
	_apply_clip_mode()

## 建剪裁框、描边、四角把手与框内拖移层
## @internal
func _build_clip_box() -> void:
	clip_box = Control.new()
	clip_box.name = "ClipBox"
	clip_box.size = Vector2(220.0, 420.0)
	clip_box.clip_contents = true
	clip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_root.add_child(clip_box)
	_center_clip_box()
	frame_border = ReferenceRect.new()
	frame_border.editor_only = false
	frame_border.border_color = Color(0.0, 0.9, 0.87, 0.9)
	frame_border.border_width = 2.0
	frame_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage_root.add_child(frame_border)
	move_grip = Control.new()
	move_grip.name = "MoveGrip"
	move_grip.mouse_filter = Control.MOUSE_FILTER_PASS
	move_grip.gui_input.connect(_on_grip_input)
	stage_root.add_child(move_grip)
	for corner: int in 4:
		var handle: Control = ColorRect.new()
		handle.name = "Handle%d" % corner
		(handle as ColorRect).color = Color(0.0, 0.9, 0.87, 0.95)
		handle.mouse_filter = Control.MOUSE_FILTER_STOP
		handle.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE if corner % 3 == 0 else Control.CURSOR_BDIAGSIZE
		handle.size = Vector2(14.0, 14.0)
		if corner == 0:
			handle.gui_input.connect(_on_handle_left_top)
		if corner == 1:
			handle.gui_input.connect(_on_handle_right_top)
		if corner == 2:
			handle.gui_input.connect(_on_handle_left_bottom)
		if corner == 3:
			handle.gui_input.connect(_on_handle_right_bottom)
		stage_root.add_child(handle)
		handles.append(handle)
	_sync_frame()

## 剪裁框默认摆到舞台中央
## @internal
func _center_clip_box() -> void:
	clip_box.position = (stage_root.size - clip_box.size) * 0.5

## 把描边、把手、拖移层贴到剪裁框上
## @internal
func _sync_frame() -> void:
	if frame_border == null or clip_box == null:
		return
	frame_border.position = clip_box.position
	frame_border.size = clip_box.size
	frame_border.visible = clip_mode
	move_grip.position = clip_box.position
	move_grip.size = clip_box.size
	move_grip.mouse_filter = Control.MOUSE_FILTER_PASS if clip_mode else Control.MOUSE_FILTER_IGNORE
	var offset: Vector2 = Vector2(7.0, 7.0)
	var corners: Array[Vector2] = [
		clip_box.position - offset,
		clip_box.position + Vector2(clip_box.size.x - offset.x, -offset.y),
		clip_box.position + Vector2(-offset.x, clip_box.size.y - offset.y),
		clip_box.position + clip_box.size - offset,
	]
	for index: int in handles.size():
		var handle: Control = handles[index]
		handle.position = corners[index]
		handle.visible = clip_mode

## 舞台尺寸变化：框没被手动调整过时保持居中
## @internal
func _on_stage_resized() -> void:
	if box_moved or clip_box == null:
		return
	_center_clip_box()
	_sync_frame()

## 按新矩形重设剪裁框，最小 40×40
func set_clip_rect(rect: Rect2) -> void:
	box_moved = true
	var min_size: float = 40.0
	clip_box.size = Vector2(maxf(rect.size.x, min_size), maxf(rect.size.y, min_size))
	clip_box.position = rect.position
	_center_case()
	_sync_frame()

## 框内拖移：整体移动剪裁框
## @internal
func _on_grip_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			drag_handle = -2
			drag_origin = stage_root.get_global_mouse_position()
			drag_rect = Rect2(clip_box.position, clip_box.size)
			return
		drag_handle = -1
		return
	if motion == null or drag_handle != -2:
		return
	var delta: Vector2 = stage_root.get_global_mouse_position() - drag_origin
	set_clip_rect(Rect2(drag_rect.position + delta, drag_rect.size))

## 左上角把手：转调到共用拉伸逻辑
## @internal
func _on_handle_left_top(event: InputEvent) -> void:
	_on_handle_input(event, 0)

## 右上角把手：转调到共用拉伸逻辑
## @internal
func _on_handle_right_top(event: InputEvent) -> void:
	_on_handle_input(event, 1)

## 左下角把手：转调到共用拉伸逻辑
## @internal
func _on_handle_left_bottom(event: InputEvent) -> void:
	_on_handle_input(event, 2)

## 右下角把手：转调到共用拉伸逻辑
## @internal
func _on_handle_right_bottom(event: InputEvent) -> void:
	_on_handle_input(event, 3)
## 四角拉伸：按对角反向的固定点缩放剪裁框
## @internal
func _on_handle_input(event: InputEvent, corner: int) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			drag_handle = corner
			drag_origin = stage_root.get_global_mouse_position()
			drag_rect = Rect2(clip_box.position, clip_box.size)
			return
		drag_handle = -1
		return
	if motion == null or drag_handle != corner:
		return
	var delta: Vector2 = stage_root.get_global_mouse_position() - drag_origin
	var left: float = drag_rect.position.x
	var top: float = drag_rect.position.y
	var right: float = drag_rect.position.x + drag_rect.size.x
	var bottom: float = drag_rect.position.y + drag_rect.size.y
	if corner == 0 or corner == 2:
		left += delta.x
	if corner == 1 or corner == 3:
		right += delta.x
	if corner == 0 or corner == 1:
		top += delta.y
	if corner == 2 or corner == 3:
		bottom += delta.y
	set_clip_rect(Rect2(Vector2(left, top), Vector2(right - left, bottom - top)))
