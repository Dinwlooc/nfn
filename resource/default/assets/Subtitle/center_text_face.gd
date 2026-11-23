## 中央文本表现：只对接 CenterTextManager，显示当前条目文本；未开局一律闪烁，开局即停闪。
extends Control

#==consts==
## 闪烁的单程时长（秒）
const BLINK_HALF_TIME: float = 0.6

#==nodes==
## 文本节点
@onready var label: Label = $Label

#==vars==
## 关联渲染根
@export var render_control: RenderControl = null
## 闪烁补间槽位
var blink_tween: Tween = null
## 渲染状态管理器
var _state: RenderStateManager = null

#==lifecycle==
## 就绪：忽略鼠标、套用文本样式并接入文本管理器
## @override
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_label()
	_bind_text_manager()

#==binding==
## 接入文本管理器与开局标志
## @signal_listener
func _bind_text_manager() -> void:
	if not render_control or not render_control.render_context:
		return
	var context: RenderContext = render_control.render_context
	_state = context.state_manager
	context.text_manager.entries_changed.connect(_refresh_text)
	_state.game_started_notified.connect(_refresh_text, CONNECT_ONE_SHOT)
	_refresh_text()

#==text==
## 按条目刷新显示；未开局闪烁，开局后常显
## @side_effect
func _refresh_text() -> void:
	var text: String = render_control.render_context.text_manager.get_first_text()
	if text.is_empty():
		hide_text()
		return
	label.text = text
	visible = true
	if _state and not _state.game_started:
		_start_blink()
		return
	_stop_blink()

## 隐藏文本并停止闪烁
## @side_effect
func hide_text() -> void:
	visible = false
	_stop_blink()
	label.modulate.a = 1.0

#==internal==
## 启动闪烁：同一时刻只保留一条补间
## @side_effect
func _start_blink() -> void:
	label.modulate.a = 1.0
	if blink_tween and blink_tween.is_valid():
		return
	blink_tween = create_tween().set_loops()
	blink_tween.tween_property(label, ^"modulate:a", 0.0, BLINK_HALF_TIME).set_trans(Tween.TRANS_SINE)
	blink_tween.tween_property(label, ^"modulate:a", 1.0, BLINK_HALF_TIME).set_trans(Tween.TRANS_SINE)

## 停止闪烁并复位透明度
## @side_effect
func _stop_blink() -> void:
	blink_tween = UIAnimationUtils.clear_tween(blink_tween)
	label.modulate.a = 1.0

## 文本样式：居中并忽略鼠标
## @internal
func _setup_label() -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
