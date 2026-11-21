## 启动区：背景图中心的透明点击区域。未开局时鼠标悬停显示手形光标；左键点击发出开始游戏请求并停用本区域。
extends Control

#==lifecycle==
## 就绪：接线点击、显示手形光标并接入开局标志
## @side_effect
func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_bind_game_start()

#==hooks==
## 左键点击：停止接收鼠标并发出开始游戏请求
## @side_effect @emitter
func _on_gui_input(event: InputEvent) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	_stop_input()
	GlobalConsole.c_start.emit()

#==internal==
## 停止接收鼠标：本区域此后对点击透明，光标恢复箭头
## @side_effect
func _stop_input() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_ARROW
## 接入开局标志：已注册则立即读取，否则等注册信号
## @signal_listener
func _bind_game_start() -> void:
	if GlobalRegistry.has_singleton(GlobalRegistry.RENDER_CONTROL_TYPE):
		_on_render_control_registered(GlobalRegistry.get_singleton(GlobalRegistry.RENDER_CONTROL_TYPE))
		return
	if not GlobalRegistry.singleton_registered.is_connected(_on_singleton_registered):
		GlobalRegistry.singleton_registered.connect(_on_singleton_registered)
## 单例注册：只处理渲染根
## @signal_listener
func _on_singleton_registered(type: String, instance: Node) -> void:
	if type != String(GlobalRegistry.RENDER_CONTROL_TYPE):
		return
	_on_render_control_registered(instance)
## 渲染根就绪：已开局则停用本区域，否则等开局通知
## @signal_listener
func _on_render_control_registered(instance: Node) -> void:
	var render_control: RenderControl = instance as RenderControl
	if not render_control:
		return
	var state: RenderStateManager = render_control.render_context.state_manager
	if state.game_started:
		_stop_input()
		return
	state.game_started_notified.connect(_stop_input, CONNECT_ONE_SHOT)
