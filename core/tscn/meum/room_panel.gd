## 菜单房间控制面板：分页承载创建 / 加入游戏的设置；地址与端口分开填写，端口留空即随机。
extends Control

## 确认进入游戏（模式、主机文本、端口文本）
## @emitter
signal confirmed(mode: EntryMode.Mode, host: String, port_text: String)
## 返回菜单
## @emitter
signal back_requested()

## 当前选中的模式
var _mode: EntryMode.Mode = EntryMode.Mode.CREATE

## 就绪：接线确认与返回，并设置输入提示
func _ready() -> void:
	$ButtonEnter.pressed.connect(_on_enter_pressed)
	$ButtonBack.pressed.connect(_on_back_pressed)
	$PageCreate/LineEdit_Port.placeholder_text = "留空则随机分配"
	$PageJoin/LineEdit_Host.placeholder_text = "localhost（可省略 ws://）"
	$PageJoin/LineEdit_Port.placeholder_text = "端口，例如 9080"

## 切换分页：创建页填端口，加入页填主机与端口
func select_mode(mode: EntryMode.Mode) -> void:
	_mode = mode
	var is_create: bool = mode == EntryMode.Mode.CREATE
	$Title.text = "创建游戏" if is_create else "加入游戏"
	$PageCreate.visible = is_create
	$PageJoin.visible = not is_create

## 取创建页填写的端口文本
func get_create_port() -> String:
	return $PageCreate/LineEdit_Port.text

## 取加入页填写的主机文本
func get_host() -> String:
	return $PageJoin/LineEdit_Host.text

## 取加入页填写的端口文本
func get_join_port() -> String:
	return $PageJoin/LineEdit_Port.text

## 端口文本可用：留空或纯数字
func _is_port_usable(text: String) -> bool:
	var trimmed: String = text.strip_edges()
	return trimmed.is_empty() or trimmed.is_valid_int()

## 加入页填写完整：主机非空且端口为数字
func _is_join_ready() -> bool:
	return not get_host().strip_edges().is_empty() and get_join_port().strip_edges().is_valid_int()

## 确认按钮：校验后上报模式、主机与本次使用的端口文本
## @emitter @signal_listener
func _on_enter_pressed() -> void:
	if not _is_port_usable(get_create_port()) or not _is_port_usable(get_join_port()):
		GlobalConsole._print("菜单:Error:端口须留空或填写数字")
		return
	if _mode == EntryMode.Mode.JOIN and not _is_join_ready():
		GlobalConsole._print("菜单:Error:请填写主机与端口")
		return
	var active_port: String = get_create_port() if _mode == EntryMode.Mode.CREATE else get_join_port()
	confirmed.emit(_mode, get_host(), active_port)

## 返回按钮：请求关闭面板
## @emitter @signal_listener
func _on_back_pressed() -> void:
	back_requested.emit()
