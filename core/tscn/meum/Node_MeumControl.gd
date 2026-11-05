## 菜单控制器：点选入口时把 LOGO 移出、按钮推向左侧边缘、房间面板从右侧滑入；确认后按进入模式进入主场景。
extends Control

## 按钮停靠到左侧边缘时的横坐标
const BUTTON_LEFT_X := 60.0
## 面板滑入后的横坐标
const PANEL_OPEN_X := 700.0
## LOGO 移出屏幕的横向位移
const LOGO_SHIFT := -900.0
## 平移时长（秒）
const SLIDE_DURATION := 0.45
## 主游戏场景路径
const GAME_SCENE := "res://core/tscn/game/main_game.tscn"

## LOGO 初始位置
var _logo_home: Vector2
## 按钮列初始位置
var _buttons_home: Vector2
## 面板初始位置（视口右侧之外）
var _panel_home: Vector2
## 当前平移补间
var _slide_tween: Tween
## 面板是否已展开
var _panel_open: bool = false

## 就绪：记录初始位置、接线按钮与面板，并播放淡出
func _ready() -> void:
	_logo_home = $ColorRect_icon.position
	_buttons_home = $MenuButtons.position
	_panel_home = $RoomPanel.position
	$MenuButtons/ButtonCreate.pressed.connect(_on_mode_pressed.bind(EntryMode.Mode.CREATE))
	$MenuButtons/ButtonJoin.pressed.connect(_on_mode_pressed.bind(EntryMode.Mode.JOIN))
	$MenuButtons/ButtonQuit.pressed.connect(_on_quit_pressed)
	$RoomPanel.confirmed.connect(_on_confirmed)
	$RoomPanel.back_requested.connect(_on_back_requested)
	GlobalTransition.fade_out()

## 点选入口：切到对应分页；面板未展开时一并播放滑入
## @side_effect
func _on_mode_pressed(mode: EntryMode.Mode) -> void:
	$RoomPanel.select_mode(mode)
	if _panel_open:
		return
	_panel_open = true
	_slide(BUTTON_LEFT_X, PANEL_OPEN_X, _logo_home.x + LOGO_SHIFT)

## 面板确认：写入进入模式与端口；创建游戏直接转场，加入游戏先连服务器
## @side_effect
func _on_confirmed(mode: EntryMode.Mode, host: String, port_text: String) -> void:
	EntryMode.current = mode
	var port: int = port_text.strip_edges().to_int()
	if mode == EntryMode.Mode.CREATE:
		EntryMode.server_port = port
		GlobalTransition.change_scene_with_transition(GAME_SCENE)
		return
	var url: String = _build_url(host, port)
	if not GlobalTransport.network_manager.url_connect(url):
		GlobalConsole._print("菜单:Error:无法连接 %s" % url)
		return
	GlobalTransition.change_scene_with_transition(GAME_SCENE)

## 拼接连接地址：主机已带端口则原样使用，缺协议前缀时补 ws://
func _build_url(host: String, port: int) -> String:
	var trimmed: String = host.strip_edges()
	var base: String = trimmed if trimmed.begins_with("ws://") or trimmed.begins_with("wss://") else "ws://" + trimmed
	if base.get_slice("://", 1).contains(":"):
		return base
	return "%s:%d" % [base, port]

## 面板返回：收起面板并复原菜单
## @side_effect
func _on_back_requested() -> void:
	_panel_open = false
	_slide(_buttons_home.x, _panel_home.x, _logo_home.x)

## 退出游戏
## @side_effect
func _on_quit_pressed() -> void:
	get_tree().quit()

## 并行平移 LOGO、按钮列与面板
## @side_effect
func _slide(buttons_x: float, panel_x: float, logo_x: float) -> void:
	if _slide_tween:
		_slide_tween.kill()
	_slide_tween = create_tween().set_parallel(true)
	_slide_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_slide_tween.tween_property($MenuButtons, "position:x", buttons_x, SLIDE_DURATION)
	_slide_tween.tween_property($RoomPanel, "position:x", panel_x, SLIDE_DURATION)
	_slide_tween.tween_property($ColorRect_icon, "position:x", logo_x, SLIDE_DURATION)
