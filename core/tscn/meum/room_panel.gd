## 菜单房间控制面板：分页承载创建 / 加入游戏的设置；地址与端口分开填写，端口留空即随机。
extends Control

## 实验室目录：扫描与显示名
const LabCatalogScript := preload("res://core/tscn/meum/LabCatalog.gd")

## 确认进入游戏（模式、主机文本、端口文本）
## @emitter
signal confirmed(mode: LaunchContext.Mode, host: String, port_text: String)
## 返回菜单
## @emitter
signal back_requested()
## 选中实验室场景（场景路径）
## @emitter
signal lab_selected(scene_path: String)

## 当前选中的模式
var _mode: LaunchContext.Mode = LaunchContext.Mode.CREATE
## 实验室分页当前列出的场景路径，下标与列表条目一一对应
var _lab_paths: Array[String] = []

## 就绪：接线确认与返回，并设置输入提示
func _ready() -> void:
	$ButtonEnter.pressed.connect(_on_enter_pressed)
	$ButtonBack.pressed.connect(_on_back_pressed)
	$PageCreate/LineEdit_Port.placeholder_text = "留空则随机分配"
	$PageJoin/LineEdit_Host.placeholder_text = "localhost（可省略 ws://）"
	$PageJoin/LineEdit_Port.placeholder_text = "端口，例如 9080"
	$PageLab/ItemList_Lab.item_activated.connect(_on_lab_activated)

## 切换分页：创建页填端口，加入页填主机与端口
func select_mode(mode: LaunchContext.Mode) -> void:
	_mode = mode
	var is_create: bool = mode == LaunchContext.Mode.CREATE
	$Title.text = "创建游戏" if is_create else "加入游戏"
	$PageCreate.visible = is_create
	$PageJoin.visible = not is_create
	$PageLab.visible = false
	$ButtonEnter.visible = true

## 切换到实验室分页：标题改名，只留实验室列表，隐藏进入游戏按钮
## @side_effect
func select_lab() -> void:
	$Title.text = "实验室"
	$PageCreate.visible = false
	$PageJoin.visible = false
	$PageLab.visible = true
	$ButtonEnter.visible = false
	_fill_lab_list()

## 取创建页填写的端口文本
func get_create_port() -> String:
	return $PageCreate/LineEdit_Port.text

## 取加入页填写的主机文本
func get_host() -> String:
	return $PageJoin/LineEdit_Host.text

## 取加入页填写的端口文本
func get_join_port() -> String:
	return $PageJoin/LineEdit_Port.text

## 按扫描结果重建实验室列表；没有场景时列一条禁用的占位项
## @side_effect
func _fill_lab_list() -> void:
	var list: ItemList = $PageLab/ItemList_Lab
	list.clear()
	_lab_paths.clear()
	_lab_paths.assign(LabCatalogScript.scan())
	for scene_path: String in _lab_paths:
		list.add_item(LabCatalogScript.display_name(scene_path))
	if _lab_paths.is_empty():
		list.add_item("未找到实验室场景")
		list.set_item_disabled(0, true)

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
	if _mode == LaunchContext.Mode.JOIN and not _is_join_ready():
		GlobalConsole._print("菜单:Error:请填写主机与端口")
		return
	var active_port: String = get_create_port() if _mode == LaunchContext.Mode.CREATE else get_join_port()
	confirmed.emit(_mode, get_host(), active_port)

## 双击列表条目：上报该条目的场景路径
## @emitter @signal_listener
func _on_lab_activated(index: int) -> void:
	if index < 0 or index >= _lab_paths.size():
		return
	lab_selected.emit(_lab_paths[index])

## 返回按钮：请求关闭面板
## @emitter @signal_listener
func _on_back_pressed() -> void:
	back_requested.emit()
