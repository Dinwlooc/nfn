extends Node
 
###全局控制台####
var maingame:Node
var	renderarea:Dictionary
var console:Node
var card_on_drag:Dictionary
var timer:GameTimer
var system:System

var command_list: Dictionary = load("res://data/Script/Global/command.tres").command as Dictionary
var command_name_list:PackedStringArray = load("res://data/Script/Global/command.tres").command_name as PackedStringArray

signal global_dragged
signal c_start
signal c_draw
signal c_connect_to(url:String)
signal c_close 
signal c_help(command:StringName)

func _ready() -> void:
	c_help.connect(print_help)
func register_console(console_instance)->void:
	console = console_instance
func register_maingame(maingame_instance)->void:
	maingame = maingame_instance
func register_system(system_instance:System)->void:
	system = system_instance
func register_timer(timer_instance)->void:
	timer = timer_instance
func register_renderarea(renderarea_name:StringName,renderarea_instance:RenderArea)->void:
	renderarea[renderarea_name] = renderarea_instance
	
func set_card_on_drag(area:RenderArea,realcard:RenderCard)->void:
	remove_card_on_drag()
	card_on_drag[&"area"] = area
	card_on_drag[&"card"] = realcard
	card_on_drag[&"card"].dragged = true
	card_on_drag[&"area"].tween_update()
	global_dragged.emit()

func get_renderarea(renderarea_name:StringName)->RenderArea:
	if renderarea.has(renderarea_name):
		return renderarea[renderarea_name]
	return null

func remove_card_on_drag():
	if card_on_drag:
		card_on_drag[&"card"].dragged = false
		card_on_drag[&"area"].tween_update()
	card_on_drag.clear()
		
func _print(text:Variant)->void:
	if console:
		match typeof(text):
			4:
				console.append_text(text)
				print(text)
				return
			28:
				var real_text:String = ""
				for i in range(text.size()):
					real_text += str(text[i])
				console.append_text(real_text)
				print(real_text)
				return
		push_error()
		
func command(signal_name:String,args:Array)->void:
	if !command_name_list.has(signal_name):#玩家输入不可控，故先验证合法性再转化
		_print(["指令未登记：",signal_name])
		return
	var signal_stringname = StringName(signal_name)
	var min_arg_num = command_list[signal_stringname][&"min"]
	var max_arg_num = command_list[signal_stringname][&"max"]
	if args.size()<min_arg_num:
		_print(["Error:参数不足，",signal_name,"未发送。目标：",min_arg_num])
		return
	if args.size()>max_arg_num:
		_print(["Error:参数过多，",signal_name,"未发送。限制：",max_arg_num])
		return
	else:
		_print(["发送指令：",signal_name])
		emit_signal.bindv(args).call(signal_stringname)
		return

func print_help(command_name:String = "c_help"):
	if !command_name_list.has(command_name):
		_print(["c_help:指令未登记：",command_name])
		return
	
	_print(["c_help:",command_list[StringName(command_name)].get(&"mes","暂无提示")])
