extends Control

## 垂直布局容器，用于显示命令建议
@onready var vbox_container: VBoxContainer = $VBoxContainer
## 日志面板（TextEdit）
@onready var panel: TextEdit = $Panel
## 命令输入行
@onready var input_line_edit: LineEdit = $Input

## 结算节点引用（外部赋值）
var settlement: Node = null
## 选择节点引用
var selection: Node = null
## 玩家面板引用
var players_panel: Node = null
## 面板显示状态
var panel_display: bool = false
## 开始节点引用
var start: Node = null
## 命令建议标签数组
var labels: Array[Node] = []
## 命令历史记录
var command_history: PackedStringArray = []
## 当前历史导航索引，0 表示输入框为空
var current_history_index: int = -1
## 是否启用历史上下浏览
var history_navigation_enabled: bool = false
## 控制台原始位置
var original_position: Vector2
## 控制台展开后位置
var display_position: Vector2
## 建议列表当前页码
var current_page: int = 0
## 当前高亮建议索引
var current_selection: int = -1
## 过滤后的建议列表
var filtered: PackedStringArray = []
## 所有可用命令名的缓存
var command_suggestions: Array = GlobalConsole.command_list.keys()
## 面板位置动画 Tween 引用
var panel_tween: Tween
## 文本变化事件标记，防止递归更新
var _ignore_text_changed: bool = false
## 命令历史最大容量
const MAX_HISTORY: int = 20
## 每页显示的建议数量
const page_size: int = 9

# ---------- 日志优化相关 ----------
## 日志追加缓冲区
var _log_buffer: PackedStringArray = PackedStringArray()
## 当前是否正在执行刷新协程
var _is_flushing: bool = false
## 定时器，定期触发刷新
var _flush_timer: Timer = null
## 单帧最多追加行数，避免 UI 处理过重
const FLUSH_CHUNK_SIZE: int = 5
## 日志最大保留行数
const MAX_LINES: int = 100
## 定时刷新间隔（秒）
const FLUSH_INTERVAL: float = 1.0
## 缓冲区立即刷新阈值
const BATCH_FLUSH_THRESHOLD: int = 20

func _ready():
	command_load()
	input_load()
	suggestion_labels_load()
	GlobalRegistry.register_singleton(GlobalRegistry.CONSOLE_TYPE, self)
	_setup_log_optimization()

## 初始化日志优化组件：禁用编辑、启动定时刷新
func _setup_log_optimization():
	panel.editable = false
	_flush_timer = Timer.new()
	_flush_timer.wait_time = FLUSH_INTERVAL
	_flush_timer.one_shot = false
	_flush_timer.timeout.connect(_on_flush_timer_timeout)
	add_child(_flush_timer)
	_flush_timer.start()

## 定时器回调，触发分帧刷新
func _on_flush_timer_timeout():
	_flush_chunked()

## 向日志缓冲区追加文本，超过阈值立即触发刷新
func append_text(text: String):
	_log_buffer.append(text)
	if _log_buffer.size() >= BATCH_FLUSH_THRESHOLD:
		_flush_chunked()

## 启动协程分帧刷新（若未在刷新且缓冲区非空）
func _flush_chunked():
	if _is_flushing or _log_buffer.is_empty():
		return
	_is_flushing = true
	_flush_async()

## 异步协程：分帧将缓冲区内容写入面板，并自动滚动到底部
func _flush_async() -> void:
	while true:
		if _log_buffer.is_empty():
			break
		var chunk_size: int = mini(_log_buffer.size(), FLUSH_CHUNK_SIZE)
		var chunk: PackedStringArray = _log_buffer.slice(0, chunk_size)
		_log_buffer = _log_buffer.slice(chunk_size)
		if panel.text.is_empty():
			panel.text = "\n".join(chunk)
		else:
			panel.text += "\n" + "\n".join(chunk)
		# 滚动到最后一行
		panel.set_caret_line(panel.get_line_count() - 1)
		await get_tree().process_frame
		if not is_inside_tree():
			break
	_trim_log_lines()
	# 修剪后再次滚动到底部（如果行数变化）
	panel.set_caret_line(panel.get_line_count() - 1)
	_is_flushing = false

## 修剪面板文本行数不超上限
func _trim_log_lines():
	var lines: PackedStringArray = panel.text.split("\n")
	if lines.size() > MAX_LINES:
		lines = lines.slice(lines.size() - MAX_LINES)
		panel.text = "\n".join(lines)

# ---------- 原有面板交互逻辑 ----------
## 动画移动面板到目标位置
func animate_panel_position(target_position: Vector2, duration: float = 0.3):
	if panel_tween and panel_tween.is_running():
		panel_tween.stop()
	panel_tween = create_tween()
	panel_tween.set_trans(Tween.TRANS_QUINT)
	panel_tween.set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(self, ^"position", target_position, duration)

## 切换面板显示/隐藏
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
		labels[i].connect(&"text_submitted", _suggestion_submitted) if labels[i].has_signal(&"text_submitted") else labels[i].connect(&"gui_input", _on_suggestion_clicked.bind(i))
		labels[i].mouse_entered.connect(labels[i].call_deferred.bind(&"grab_focus"))

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
		filtered = command_suggestions.filter(func(s): return s.to_lower().begins_with(new_text.to_lower()))
	else:
		filtered = command_suggestions.duplicate()
	toggle_suggestions(not filtered.is_empty())
	filtered.append("...")
	current_history_index = 0

func _suggestion_submitted(suggestion: String):
	input_line_edit.text = suggestion + "()"
	input_line_edit.call_deferred(&"grab_focus")
	input_line_edit.caret_column = suggestion.length() + 1
	current_page = 0
	input_line_edit.text_changed.emit(input_line_edit.text)

func _on_suggestion_clicked(event: InputEvent, index: int):
	if event is InputEventMouseButton and event.pressed and event.button_mask == 1:
		var suggestion = labels[index].text
		if suggestion == "...":
			current_page = 0
			update_page_display(0)
			return
		_suggestion_submitted(suggestion)

func _on_suggestion_focused(index: int):
	labels[index].select_all()
	if labels[index].text == "..." or not labels[index].visible:
		input_line_edit.call_deferred(&"grab_focus")
		current_page = 0
		return
	if current_selection == 0 and index == 8 and current_page:
		current_page -= 1
	if current_selection == 8 and index == 0:
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

## 更新建议列表显示指定页
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
