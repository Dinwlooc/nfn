extends Control

@onready var Nvbox:Control = $VBoxContainer
@onready var Npanel:Control = $Panel
@onready var Ninput:LineEdit = $Input
var settlement:Node
var selection:Node
var players_panel:Node
var panel_display = false
var start:Node
var labels:Array
var command_history: Array = []
var current_history_index: int = -1
var history_navigation_enabled: bool = false
var original_position:Vector2
var display_position:Vector2
var current_page: int = 0
var current_selection: int = -1
var filtered:Array
var command_suggestions: Array = GlobalConsole.command_list.keys()

const MAX_HISTORY: int = 100
const page_size: int = 9

func _ready():
	command_load()
	input_load()
	suggestion_labels_load()
	GlobalConsole.register_console(self)  # 注册到全局控制台系统
	pass
	
func _process(_delta):
	panel_animation_control()
	pass
	
func panel_animation_control():
	if panel_display:
		position = GlobalUIAnimation.smooth_move_animation(position,display_position,GlobalUIAnimation.GOLDEN_SPEED_3FRAMES)
	else:
		position = GlobalUIAnimation.smooth_move_animation(position,original_position,GlobalUIAnimation.GOLDEN_SPEED_3FRAMES)
	pass

func command_load():
	original_position = Vector2(0,900) - size
	display_position = Vector2(0,900) - Vector2(0,size.y)
	pass
	
func input_load():
	Ninput.text_submitted.connect( _on_command_submitted)
	Ninput.focus_entered.connect(_on_focus_entered)
	Ninput.focus_exited.connect(_on_focus_exited)
	Ninput.text_changed.connect(_on_text_changed)

func suggestion_labels_load():
	labels = Nvbox.get_children()
	Nvbox.visible = false
	for i in range(Nvbox.get_child_count()):
		labels[i].mouse_filter = Control.MOUSE_FILTER_STOP
		labels[i].focus_mode = Control.FOCUS_ALL
		labels[i].visible = false
		labels[i].connect(&"focus_entered", _on_suggestion_focused.bind(i))
		labels[i].text_submitted.connect( _suggestion_submitted)
		labels[i].gui_input.connect(_on_suggestion_clicked.bind(i)) # 新增点击事件连接
		labels[i].mouse_entered.connect(labels[i].call_deferred.bind(&"grab_focus")) 

#####信号触发函数####
func _on_focus_entered():
	history_navigation_enabled = true
	current_history_index = -1  # 重置历史导航位置
 
func _on_focus_exited():
	history_navigation_enabled = false
 
func _on_text_changed(new_text:String):
	if new_text.to_lower().begins_with("c"):
		filtered = []
		if new_text.length() > 2:
			filtered = command_suggestions.filter(func(s):
				return s.to_lower().begins_with(new_text.to_lower()))
		else:
			filtered = command_suggestions.duplicate()
		var condition = filtered.is_empty()
		toggle_suggestions(!condition)
		filtered.append("...")
	else:
		toggle_suggestions(false)
	# 当用户手动修改输入时重置历史导航
	current_history_index = 0

func _suggestion_submitted(suggestion:String):
	Ninput.text = suggestion+"()"
	Ninput.call_deferred(&"grab_focus")
	Ninput.caret_column = suggestion.length() + 1
	current_page = 0
	Ninput.emit_signal(&"text_changed",Ninput.text)

func _on_suggestion_clicked(event: InputEvent, index: int):
	if event is InputEventMouseButton and event.pressed && event.button_mask == 1:
		var suggestion = labels[index].text
		if suggestion == "...":  # 处理翻页指示符
			current_page = 0
			update_page_display(0)
			return
		# 提交选中建议
		_suggestion_submitted(suggestion)

func _on_suggestion_focused(index: int):
	labels[index].select_all()
	if labels[index].text == "..."||!labels[index].visible:
		Ninput.call_deferred(&"grab_focus")
		current_page = 0
		return	
	if current_selection == 0 && index== 8 && current_page:
		current_page += -1
	if current_selection == 8 && index== 0 :
		current_page += 1
	current_selection = index
		#用焦点判断当前选择项。
	update_page_display(current_page)
		
		
func _on_command_submitted(new_text:String):
	var command_with_args = new_text.strip_edges().to_lower()
	if not command_with_args.is_empty():
		command_history.append(command_with_args)
		if command_history.size() > MAX_HISTORY:
			command_history.remove_at(0)
		current_history_index = 0
		
		var parts = command_with_args.split("(", false, 1)
		var command = parts[0].to_lower()
		var args_str = ""
		if parts.size() > 1:
			args_str = parts[1].trim_suffix(")").strip_edges()
		var args:Array = []
		if args_str:
			args = args_str.split(",", false)
		for i in range(args.size()):
			args[i] = args[i].strip_edges()
		GlobalConsole.command(command,args)
		Ninput.text = ""  # 清空输入框
 #####主要功能函数#####

func update_page_display(page:int):#建议列表翻页
	var start = page * page_size
	var end = min(start + page_size, filtered.size())
	for i in range(labels.size()):
		if i < end - start:
			labels[i].text = filtered[start + i]
			labels[i].visible = true
		else:
			labels[i].text = ""
			labels[i].visible = false
			
func toggle_suggestions(_show: bool):#建议列表显示
	Nvbox.visible = _show
	if show:
		current_selection = -1
		update_page_display(0)

func navigate_history(is_up: bool):
	if command_history.size() == 0:
		return
	# 更新历史索引
	if is_up:
		current_history_index = clamp(current_history_index - 1, -command_history.size(), 0)
	else:
		current_history_index = clamp(current_history_index + 1, -command_history.size(), 0)
	# 更新输入框内容
	if current_history_index == 0:
		Ninput.text = ""
	else:
		Ninput.text = command_history[current_history_index]

func _input(event):
	if Input.is_action_just_pressed(&"ui_get_panel"):
		panel_display = (panel_display==false)
		if panel_display:
			Ninput.call_deferred(&"grab_focus")
		else:
			get_parent().call_deferred(&"grab_focus")
	if event is InputEventKey && event.pressed:
		if Ninput.has_focus():#处理输入框的动作事件
			match event.keycode:
				KEY_TAB:#避免不可见节点夺取焦点导致焦点丢失
					if Nvbox.visible:
						Ninput.focus_next = labels[0].get_path()
					else:
						Ninput.focus_next = Ninput.get_path()
						if Ninput.text == "":
							Ninput.emit_signal(&"text_changed","c")
				KEY_UP:
					navigate_history(true)
				KEY_DOWN:
					navigate_history(false)
			return
	if event is InputEventMouseButton && event.pressed:
		var local_pos = Nvbox.get_local_mouse_position()
		if Rect2(Vector2(), Nvbox.size).has_point(local_pos):
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				current_page = max(current_page - 1, 0)
				update_page_display(current_page)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var max_page = int(ceil(float(filtered.size()) / page_size)) - 1
				current_page = min(current_page + 1, max_page)
				update_page_display(current_page)

# 以下为全局打印系统
func append_text(text: String):
	Npanel.text += "\n"+text
	# 保持滚动条在底部
	Npanel.scroll_vertical = Npanel.get_line_count()
