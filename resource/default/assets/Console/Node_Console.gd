extends Control

@onready var vbox_container: VBoxContainer = $VBoxContainer
@onready var panel: TextEdit = $Panel
@onready var input_line_edit: LineEdit = $Input

var settlement: Node
var selection: Node
var players_panel: Node
var panel_display: bool = false
var start: Node
var labels: Array
var command_history: Array = []
var current_history_index: int = -1
var history_navigation_enabled: bool = false
var original_position: Vector2
var display_position: Vector2
var current_page: int = 0
var current_selection: int = -1
var filtered: Array
var command_suggestions: Array = GlobalConsole.command_list.keys()
var panel_tween: Tween
var _ignore_text_changed: bool = false

const MAX_HISTORY: int = 100
const page_size: int = 9

# ---------- 优化日志输出相关 ----------
var _log_buffer: Array[String] = []
var _flush_timer: Timer = null
const MAX_LINES: int = 500               # 最大保留行数
const FLUSH_INTERVAL: float = 0.15      # 刷新间隔（秒）
const BATCH_FLUSH_THRESHOLD: int = 20    # 缓冲区超过此数量立即刷新

func _ready():
	command_load()
	input_load()
	suggestion_labels_load()
	GlobalRegistry.register_singleton(GlobalRegistry.CONSOLE_TYPE, self)
	_setup_log_optimization()

func _setup_log_optimization():
	panel.editable = false
	_flush_timer = Timer.new()
	_flush_timer.wait_time = FLUSH_INTERVAL
	_flush_timer.one_shot = false
	_flush_timer.timeout.connect(_flush_log_buffer)
	add_child(_flush_timer)
	_flush_timer.start()

func animate_panel_position(target_position: Vector2, duration: float = 0.3):
	if panel_tween and panel_tween.is_running():
		panel_tween.stop()
	panel_tween = create_tween()
	panel_tween.set_trans(Tween.TRANS_QUINT)
	panel_tween.set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(self, ^"position", target_position, duration)

func toggle_panel_display():
	panel_display = !panel_display
	if panel_display:
		show_panel()
	else:
		hide_panel()

func show_panel():
	animate_panel_position(display_position)
	input_line_edit.call_deferred(&"grab_focus")

func hide_panel():
	animate_panel_position(original_position)
	get_parent().call_deferred(&"grab_focus")

func command_load():
	original_position = Vector2(0, 900) - size
	display_position = Vector2(0, 900) - Vector2(0, size.y)

func input_load():
	input_line_edit.text_submitted.connect(_on_command_submitted)
	input_line_edit.focus_entered.connect(_on_focus_entered)
	input_line_edit.focus_exited.connect(_on_focus_exited)
	input_line_edit.text_changed.connect(_on_text_changed)

func suggestion_labels_load():
	labels = vbox_container.get_children()
	vbox_container.visible = false
	for i in range(vbox_container.get_child_count()):
		labels[i].mouse_filter = Control.MOUSE_FILTER_STOP
		labels[i].focus_mode = Control.FOCUS_ALL
		labels[i].visible = false
		labels[i].connect(&"focus_entered", _on_suggestion_focused.bind(i))
		labels[i].text_submitted.connect(_suggestion_submitted)
		labels[i].gui_input.connect(_on_suggestion_clicked.bind(i))
		labels[i].mouse_entered.connect(labels[i].call_deferred.bind(&"grab_focus"))

##### 信号触发函数 #####
func _on_focus_entered():
	history_navigation_enabled = true
	current_history_index = -1

func _on_focus_exited():
	history_navigation_enabled = false

func _on_text_changed(new_text: String):
	if _ignore_text_changed:
		return
	if not new_text.to_lower().begins_with("c"):
		toggle_suggestions(false)
		current_history_index = 0
		return
	filtered = []
	if new_text.length() > 2:
		filtered = command_suggestions.filter(func(s):
			return s.to_lower().begins_with(new_text.to_lower()))
	else:
		filtered = command_suggestions.duplicate()

	var condition = filtered.is_empty()
	toggle_suggestions(!condition)
	filtered.append("...")
	current_history_index = 0

func _suggestion_submitted(suggestion: String):
	input_line_edit.text = suggestion + "()"
	input_line_edit.call_deferred(&"grab_focus")
	input_line_edit.caret_column = suggestion.length() + 1
	current_page = 0
	input_line_edit.text_changed.emit(input_line_edit.text)

func _on_suggestion_clicked(event: InputEvent, index: int):
	if event is InputEventMouseButton and event.pressed && event.button_mask == 1:
		var suggestion = labels[index].text
		if suggestion == "...":
			current_page = 0
			update_page_display(0)
			return
		_suggestion_submitted(suggestion)

func _on_suggestion_focused(index: int):
	labels[index].select_all()
	if labels[index].text == "..." || !labels[index].visible:
		input_line_edit.call_deferred(&"grab_focus")
		current_page = 0
		return

	if current_selection == 0 && index == 8 && current_page:
		current_page -= 1
	if current_selection == 8 && index == 0:
		current_page += 1
	current_selection = index
	update_page_display(current_page)

func _on_command_submitted(new_text: String):
	var command_with_args = new_text.strip_edges().to_lower()
	if command_with_args.is_empty():
		return

	command_history.append(command_with_args)
	if command_history.size() > MAX_HISTORY:
		command_history.remove_at(0)
	current_history_index = 0

	var parts = command_with_args.split("(", false, 1)
	var command = parts[0].to_lower()
	var args_str = parts[1] if parts.size() > 1 else ""
	args_str = args_str.trim_suffix(")").strip_edges()
	var args: Array = []
	if args_str:
		args = args_str.split(",", false)
		for i in range(args.size()):
			args[i] = args[i].strip_edges()
	GlobalConsole.command(command, args)
	input_line_edit.text = ""

##### 主要功能函数 #####
func update_page_display(page: int):
	var start = page * page_size
	var end = min(start + page_size, filtered.size())
	for i in range(labels.size()):
		if i < end - start:
			labels[i].text = filtered[start + i]
			labels[i].visible = true
		else:
			labels[i].text = ""
			labels[i].visible = false

func toggle_suggestions(_show: bool):
	vbox_container.visible = _show
	if _show:
		current_selection = -1
		update_page_display(0)

func navigate_history(is_up: bool):
	if command_history.size() == 0:
		return
	match is_up:
		true:
			current_history_index = clamp(current_history_index - 1, -command_history.size(), 0)
		false:
			current_history_index = clamp(current_history_index + 1, -command_history.size(), 0)
	input_line_edit.text = "" if current_history_index == 0 else command_history[current_history_index]

func _input(event):
	if not event.is_pressed():
		return
	if Input.is_action_just_pressed(&"ui_get_panel"):
		toggle_panel_display()
	if event is InputEventKey:
		if input_line_edit.has_focus():
			match event.keycode:
				KEY_TAB:
					if vbox_container.visible:
						return
					if input_line_edit.text == "":
						input_line_edit.text_changed.emit("c")
					else:
						_ignore_text_changed = true
						input_line_edit.text = ""
						_ignore_text_changed = false
						input_line_edit.text_changed.emit("c")
				KEY_UP:
					navigate_history(true)
				KEY_DOWN:
					navigate_history(false)
		return
	if event is InputEventMouseButton:
		var local_pos = vbox_container.get_local_mouse_position()
		if Rect2(Vector2(), vbox_container.size).has_point(local_pos):
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					current_page = max(current_page - 1, 0)
					update_page_display(current_page)
				MOUSE_BUTTON_WHEEL_DOWN:
					var max_page = int(ceil(float(filtered.size()) / page_size)) - 1
					current_page = min(current_page + 1, max_page)
					update_page_display(current_page)
		return

# ---------- 优化的全局打印系统 ----------
func append_text(text: String):
	_log_buffer.append(text)
	if _log_buffer.size() >= BATCH_FLUSH_THRESHOLD:
		_flush_log_buffer()

func _flush_log_buffer():
	if _log_buffer.is_empty():
		return
	# 合并缓冲区文本
	var new_text = "\n".join(_log_buffer)
	_log_buffer.clear()
	# 追加到 TextEdit
	panel.text += "\n" + new_text
	# 限制总行数（避免内存膨胀）
	var lines = panel.text.split("\n")
	if lines.size() > MAX_LINES:
		panel.text = "\n".join(lines.slice(-MAX_LINES))
