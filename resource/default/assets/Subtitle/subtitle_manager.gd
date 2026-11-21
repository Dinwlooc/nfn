## 字幕管理器：按模式显示一段翻译文本。闲时提示走闪烁通道，其余模式常显；当前只接入闲时提示。
extends Control

#==enums==
## 字幕模式：闲时提示 / 卡牌描述 / 目标描述
enum TextMode { IDLE_HINT, CARD_DESCRIPTION, TARGET_DESCRIPTION }

#==consts==
## 闲时提示闪烁的单程时长（秒）
const BLINK_HALF_TIME: float = 0.6

#==nodes==
## 文本节点
@onready var label: Label = $Label

#==vars==
## 关联渲染根（取开局标志）
@export var render_control: RenderControl = null
## 闲时提示的翻译键
@export var idle_hint_key: StringName = &"nfn:hint_click_center_start"
## 闪烁补间槽位
var blink_tween: Tween = null
## 当前字幕模式
var mode: TextMode = TextMode.IDLE_HINT

#==lifecycle==
## 就绪：忽略鼠标、套用文本样式并接入开局标志
## @override
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_label()
	_watch_game_start()

#==hooks==
## 接入开局标志：未开局显示闲时提示，已开局直接隐藏
## @signal_listener
func _watch_game_start() -> void:
	if not render_control:
		return
	var state: RenderStateManager = render_control.render_context.state_manager
	if state.game_started:
		hide_text()
		return
	show_text(TextMode.IDLE_HINT, idle_hint_key)
	if not state.game_started_notified.is_connected(_on_game_started):
		state.game_started_notified.connect(_on_game_started, CONNECT_ONE_SHOT)
## 开局：隐藏字幕
## @signal_listener
func _on_game_started() -> void:
	hide_text()

#==text==
## 显示字幕：按翻译键取文本；闲时提示闪烁，其余模式常显
## @side_effect
func show_text(p_mode: TextMode, key: StringName) -> void:
	mode = p_mode
	label.text = GlobalConfig.get_translation(key)
	label.modulate.a = 1.0
	visible = true
	blink_tween = UIAnimationUtils.clear_tween(blink_tween)
	if mode != TextMode.IDLE_HINT:
		return
	blink_tween = create_tween().set_loops()
	blink_tween.tween_property(label, ^"modulate:a", 0.0, BLINK_HALF_TIME).set_trans(Tween.TRANS_SINE)
	blink_tween.tween_property(label, ^"modulate:a", 1.0, BLINK_HALF_TIME).set_trans(Tween.TRANS_SINE)
## 隐藏字幕并停止闪烁
## @side_effect
func hide_text() -> void:
	visible = false
	blink_tween = UIAnimationUtils.clear_tween(blink_tween)
	label.modulate.a = 1.0

#==internal==
## 文本样式：居中并忽略鼠标
## @internal
func _setup_label() -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
