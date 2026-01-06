extends Node
 #GlobalConsole
###全局控制台####
var command_resource:Resource = load("res://core/Global/command.tres")
var command_list: Dictionary = command_resource.command as Dictionary
var command_name_list:PackedStringArray = command_resource.command_name as PackedStringArray
var console:Node

signal global_dragged
signal c_start
signal c_draw
signal c_connect_to(url:String)
signal c_close
signal c_help(command:StringName)
signal c_play_selected_card()
signal c_reload()

func _ready() -> void:
	c_help.connect(print_help)
	GlobalRegistry.connect_singleton(GlobalRegistry.CONSOLE_TYPE,func(_console):console=_console)

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
	else :
		print(text)

func command(signal_name:String,args:Array)->void:
	if !command_name_list.has(signal_name):#玩家输入不可控，故先验证合法性再转化
		_print(["Console：指令未登记：",signal_name])
		return
	var signal_stringname = StringName(signal_name)
	var min_arg_num = command_list[signal_stringname][&"min"]
	var max_arg_num = command_list[signal_stringname][&"max"]
	if args.size()<min_arg_num:
		_print(["Console：Error:参数不足，",signal_name,"未发送。目标：",min_arg_num])
		return
	if args.size()>max_arg_num:
		_print(["Console：Error:参数过多，",signal_name,"未发送。限制：",max_arg_num])
		return
	else:
		_print(["Console：发送指令：",signal_name])
		emit_signal.bindv(args).call(signal_stringname)
		return

func print_help(command_name:String = "c_help"):
	if !command_name_list.has(command_name):
		_print(["c_help:指令未登记：",command_name])
		return
	_print(["c_help:",command_list[StringName(command_name)].get(&"mes","暂无提示")])
