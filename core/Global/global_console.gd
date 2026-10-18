## 全局控制台：调试指令的登记、解析与信号转发。
extends Node
 #GlobalConsole
###全局控制台####
var command_resource:Resource = load("res://core/Global/command.tres")
## 已登记指令表：指令名 → 参数个数上下限与说明
var command_list: Dictionary = command_resource.command as Dictionary
## 已登记指令名集合，用于校验入口指令
var command_name_list:PackedStringArray = command_resource.command_name as PackedStringArray
## 已接入的控制台面板，未接入时为 null
var console:Node

## 控制台被拖拽（预留，当前无发射点）
signal global_dragged
## 传唤：对指定玩家造成生命/法力伤害
## @requester
signal c_damage(hp_damage:int,mp_damage:int,player_id:int)
## 传唤：开始一局游戏
## @requester
signal c_start
## 传唤：令当前玩家抽牌
## @requester
signal c_draw
## 传唤：连接指定服务器地址
## @requester
signal c_connect_to(url:String)
## 传唤：断开连接
## @requester
signal c_close
## 传唤：查询指令帮助
## @requester
signal c_help(command:StringName)
## 传唤：选中手牌
## @requester
signal c_select_hand_card(card_index: int)
## 传唤：选中目标玩家
## @requester
signal c_select_target(target_player_id: int)
## 传唤：打出已选中的牌
## @requester
signal c_play_selected_card(card_index: int, target_player_id: int)
## 传唤：弃置指定手牌
## @requester
signal c_discard_cards(card_index: int)
## 传唤：放弃响应权
## @requester
signal c_abandon_response()
## 传唤：重载资源包（预留，当前无监听者）
signal c_reload()

## 接入控制台面板并注册帮助指令
func _ready() -> void:
	c_help.connect(print_help)
	GlobalRegistry.connect_singleton(GlobalRegistry.CONSOLE_TYPE,func(_console):console=_console)

## 输出到控制台面板；未接入面板时退回 print。接受单值或值数组
## @side_effect
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

## 校验参数个数，把数字字符串转成整数，再将指令转发为对应信号
## @requester
func command(signal_name: String, args: Array) -> void:
	if not command_name_list.has(signal_name):  # 验证命令是否已登记
		_print(["Console：指令未登记：", signal_name])
		return
	var signal_stringname = StringName(signal_name)
	var min_arg_num = command_list[signal_stringname]["min"]
	var max_arg_num = command_list[signal_stringname]["max"]
	if args.size() < min_arg_num:
		_print(["Console：Error:参数不足，", signal_name, "未发送。目标：", min_arg_num])
		return
	if args.size() > max_arg_num:
		_print(["Console：Error:参数过多，", signal_name, "未发送。限制：", max_arg_num])
		return
	_print(["Console：发送指令：", signal_name])
	for i in range(args.size()):
		var arg = args[i]
		if arg is String and arg.is_valid_int():
			args[i] = int(arg)   # 替换为整数
	emit_signal.bindv(args).call(signal_stringname)

## 打印已登记指令的说明文本
## @side_effect
func print_help(command_name:String = "c_help"):
	if !command_name_list.has(command_name):
		_print(["c_help:指令未登记：",command_name])
		return
	_print(["c_help:",command_list[StringName(command_name)].get(&"mes","暂无提示")])
