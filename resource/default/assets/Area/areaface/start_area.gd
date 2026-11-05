## 启动区：背景图中心的透明点击区域。左键点击发出开始游戏请求；开局前背景不进入泛光脉冲，首个主阶段到来后开启脉冲并停用本区域。
extends Control

## 场景未配置脉冲速度时的兜底值
const PULSE_SPEED_FALLBACK := 1.0
## 关联渲染根（取渲染上下文以监听主阶段通知）
@export var render_control: RenderControl = null
## 关联背景泛光节点（脉冲的作用对象）
@export var background_effect: CanvasItem = null
## 就绪：接线点击、关闭开局前的泛光脉冲并接入首个主阶段
## @side_effect
func _ready() -> void:
	gui_input.connect(_on_gui_input)
## 左键点击：停止接收鼠标并发出开始游戏请求
## @side_effect @emitter
func _on_gui_input(event: InputEvent) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event or not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	_stop_input()
	GlobalConsole.c_start.emit()
## 停止接收鼠标：本区域此后对点击透明
## @side_effect
func _stop_input() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
