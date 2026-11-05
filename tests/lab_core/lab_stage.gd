## 通用实验室舞台：用例来自全局配置表，交互与无头共用同一份。
## 引导（键位、实参、上报、退出码）由 LabShell 承担，本类只负责用例列表、舞台与读数。
class_name LabStage
extends LabShell

#==vars==
## 已加载用例
var _cases: Array[LabCase] = []
## 执行器
var _runner: LabRunner
## 用例列表按钮容器
var _case_box: VBoxContainer
## 舞台容器（用例场景实例挂在这里）
var _stage_root: Control
## 读数区
var _readout: RichTextLabel
## 当前选中的用例下标
var _current: int = 0

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
## 用例场景实例的挂载容器（LabRunner 使用）
## @pure
func get_case_container() -> Control:
	return _stage_root

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
	_case_box = VBoxContainer.new()
	_case_box.custom_minimum_size = Vector2(260.0, 0.0)
	body.add_child(_case_box)
	_stage_root = Control.new()
	_stage_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stage_root.clip_contents = false
	body.add_child(_stage_root)
	_readout = RichTextLabel.new()
	_readout.bbcode_enabled = false
	_readout.custom_minimum_size = Vector2(0.0, 160.0)
	_readout.add_theme_font_size_override("normal_font_size", 16)
	root.add_child(_readout)

## 用例按钮：点击即执行
## @internal
func _fill_case_list() -> void:
	for child: Node in _case_box.get_children():
		child.queue_free()
	for index: int in _cases.size():
		var button: Button = Button.new()
		button.text = "%d. %s" % [index + 1, _cases[index].case_id]
		button.pressed.connect(_on_case_button.bind(index))
		_case_box.add_child(button)

## 按钮回调
## @internal
func _on_case_button(index: int) -> void:
	_current = index
	_run_current()
