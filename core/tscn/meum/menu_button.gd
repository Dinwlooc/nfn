## 菜单按钮：扁平无图标、文字居中；悬停时底贴图垫在文字之下，从中心弹射展开（横向超量回弹、纵向一步到位），离开时折叠并完全透明。
extends Button

## 底图颜色（决定高光色相）
@export var glow_color: Color = Color(0.0, 0.9, 0.87451)
## 按钮字号（菜单与面板按钮统一）
const FONT_SIZE := 42
## 展开时长（秒）
const OPEN_DURATION := 0.5
## 收起时长（秒）
const CLOSE_DURATION := 0.35
## 横向超量展开倍率（回弹目标为 1.0）
const OVERSHOOT_X := 1.25
## 超量到极致时的透明度（最不透明）
const PEAK_ALPHA := 1.0
## 回弹稳定后的透明度（相对更透明）
const SETTLED_ALPHA := 0.45

## 底部高光贴图（垫在文字之下，缩放代表展开度，支点在中心）
var _highlight: TextureRect
## 纵向补间
var _vertical_tween: Tween
## 横向补间（超量 + 回弹两段）
var _horizontal_tween: Tween
## 透明度补间（低亮 → 全亮 / 收至全透明）
var _alpha_tween: Tween

## 就绪：扁平化、文字居中、生成底贴图并接入悬停事件
func _ready() -> void:
	flat = true
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_color_override(&"font_color", Color(1, 1, 1, 1))
	add_theme_font_size_override(&"font_size", FONT_SIZE)
	_setup_highlight()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

## 生成底贴图：铺满按钮矩形、画在按钮自身之前，初始完全收起
## @side_effect
func _setup_highlight() -> void:
	_highlight = TextureRect.new()
	_highlight.texture = _build_highlight_texture()
	_highlight.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_highlight.stretch_mode = TextureRect.STRETCH_SCALE
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight.show_behind_parent = true
	_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	_highlight.modulate.a = 0.0
	_highlight.scale = Vector2.ZERO
	add_child(_highlight)
	resized.connect(_sync_highlight_pivot)
	_sync_highlight_pivot()

## 生成自上而下渐隐的底贴图
func _build_highlight_texture() -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color(glow_color, 0.0), Color(glow_color, 0.9)])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	texture.width = 8
	texture.height = 64
	return texture

## 把缩放支点固定在按钮中心，使展开自中心向四周弹射
## @side_effect
func _sync_highlight_pivot() -> void:
	if not _highlight:
		return
	_highlight.pivot_offset = size * 0.5

## 悬停：底贴图自中心弹射展开
## @side_effect @signal_listener
func _on_mouse_entered() -> void:
	_open_highlight()

## 移出：从当前实际状态折叠并淡出
## @side_effect @signal_listener
func _on_mouse_exited() -> void:
	_close_highlight()

## 展开：纵向一步到位，横向以两倍速度冲到超量倍率再回弹；
## 透明度在超量到极致时最高，回弹稳定后回落到较透明
## @side_effect
func _open_highlight() -> void:
	if not _highlight:
		return
	_kill_highlight_tweens()
	_vertical_tween = create_tween()
	_vertical_tween.tween_property(_highlight, ^"scale:y", 1.0, OPEN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_horizontal_tween = create_tween()
	_horizontal_tween.tween_property(_highlight, ^"scale:x", OVERSHOOT_X, OPEN_DURATION * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_horizontal_tween.tween_property(_highlight, ^"scale:x", 1.0, OPEN_DURATION * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_alpha_tween = create_tween()
	_alpha_tween.tween_property(_highlight, ^"modulate:a", PEAK_ALPHA, OPEN_DURATION * 0.5)
	_alpha_tween.tween_property(_highlight, ^"modulate:a", SETTLED_ALPHA, OPEN_DURATION * 0.5)

## 收起：横向先快收、纵向随后折叠，透明度同步收到全透明
## @side_effect
func _close_highlight() -> void:
	if not _highlight:
		return
	_kill_highlight_tweens()
	_vertical_tween = create_tween()
	_vertical_tween.tween_property(_highlight, ^"scale:y", 0.0, CLOSE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_horizontal_tween = create_tween()
	_horizontal_tween.tween_property(_highlight, ^"scale:x", 0.0, CLOSE_DURATION * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_alpha_tween = create_tween()
	_alpha_tween.tween_property(_highlight, ^"modulate:a", 0.0, CLOSE_DURATION)

## 中断仍在进行的补间，避免叠加
## @side_effect
func _kill_highlight_tweens() -> void:
	if _vertical_tween:
		_vertical_tween.kill()
	if _horizontal_tween:
		_horizontal_tween.kill()
	if _alpha_tween:
		_alpha_tween.kill()
