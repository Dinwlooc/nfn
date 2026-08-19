## 块指示器：管理一组块（Panel）的容量、布局和颜色设置。
## 支持直接设置、渐变（Tween）和闪烁（工具类）三种颜色修改方式。
extends Control

## 块相对于格子宽高的缩放系数。
@export var block_scale: float = 0.8
## 默认闪烁时长（秒）。
@export var blink_duration: float = 0.2
## 渐变动画时长（秒）。
@export var gradient_duration: float = 0.067

## 承载块的背景容器。
@onready var fill_background: Control = $FillBackground
## 块模板（隐藏）。
@onready var template: Panel = $Template
## 数值标签（可选）。
@onready var value_label: Label = $ValueLabel

## 当前所有块实例
var blocks: Array[Panel] = []
## 当前容量（块数）
var capacity: int = 0
## 背景样式缓存
var _background_stylebox: StyleBoxFlat = null
## 场景中定义的原色（用于背景混合黑色）
var base_bg_color: Color = Color.WHITE

## 每个块的基础颜色（供外部读取）
var block_base_colors: Array[Color] = []
## 标记每个块是否正在播放动画（渐变/闪烁），避免动画冲突
var block_animating: Array[bool] = []
## 每个块的基础位置（布局计算所得，供外部动画使用）
var block_base_positions: Array[Vector2] = []
## 每个块当前正在播放的 Tween（用于闪烁动画管理）
var _block_tweens: Array[Tween] = []

func _ready() -> void:
	_ensure_background_style()

## 设置容量，调整块数量并重新布局。
func set_capacity(new_max: int) -> void:
	if new_max < 0:
		return
	capacity = new_max
	_adjust_blocks(new_max)
	_layout_blocks()
	# 同步内部数组长度
	while block_base_colors.size() < blocks.size():
		block_base_colors.append(Color.TRANSPARENT)
		block_animating.append(false)
		block_base_positions.append(Vector2.ZERO)
		_block_tweens.append(null)
	while block_base_colors.size() > blocks.size():
		block_base_colors.pop_back()
		block_animating.pop_back()
		block_base_positions.pop_back()
		_block_tweens.pop_back()

## 直接设置单个块的颜色（无动画）。
func set_block_color(index: int, color: Color) -> void:
	if index < 0 or index >= blocks.size():
		return
	_cancel_block_animation(index)
	block_base_colors[index] = color
	var block: Panel = blocks[index]
	var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel") as StyleBoxFlat
	stylebox.bg_color = color

## 渐变设置单个块的颜色（快速 Tween）。
func set_block_color_gradient(index: int, color: Color, duration: float = gradient_duration) -> void:
	if index < 0 or index >= blocks.size():
		return
	_cancel_block_animation(index)
	block_animating[index] = true
	var block: Panel = blocks[index]
	var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel") as StyleBoxFlat
	var from_color: Color = stylebox.bg_color
	block_base_colors[index] = color
	var tween: Tween = create_tween()
	tween.tween_property(stylebox, ^"bg_color", color, duration) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(_on_color_animation_finished.bind(index), CONNECT_ONE_SHOT)

## 两步渐变：先快速过渡到闪色，再渐变到目标色
func set_block_color_two_step(index: int, flash_color: Color, target_color: Color, flash_duration: float = 0.05, gradient_duration: float = gradient_duration) -> void:
	if index < 0 or index >= blocks.size():
		return
	_cancel_block_animation(index)
	block_animating[index] = true
	var block: Panel = blocks[index]
	var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel") as StyleBoxFlat
	var tween: Tween = create_tween()
	tween.tween_property(stylebox, ^"bg_color", flash_color, flash_duration) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(stylebox, ^"bg_color", target_color, gradient_duration) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	block_base_colors[index] = target_color
	tween.finished.connect(_on_color_animation_finished.bind(index), CONNECT_ONE_SHOT)
	_block_tweens[index] = tween

## 闪烁设置单个块的颜色（使用工具类，返回 Tween 并自动管理）。
func blink_block(index: int, from_color: Color, to_color: Color, duration: float = blink_duration) -> void:
	if index < 0 or index >= blocks.size():
		return
	_cancel_block_animation(index)
	block_animating[index] = true
	var block: Panel = blocks[index]
	var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel") as StyleBoxFlat
	stylebox.bg_color = from_color
	block_base_colors[index] = to_color
	var tween: Tween = UIAnimationUtils.blink_stylebox_bg_color(block, from_color, to_color, duration)
	_block_tweens[index] = tween
	tween.finished.connect(_on_blink_finished.bind(index), CONNECT_ONE_SHOT)

func _on_color_animation_finished(index: int) -> void:
	block_animating[index] = false

func _on_blink_finished(index: int) -> void:
	if index >= 0 and index < block_animating.size():
		block_animating[index] = false
		_block_tweens[index] = null

## 取消指定块的动画（如果正在运行）
func _cancel_block_animation(index: int) -> void:
	if index < 0 or index >= _block_tweens.size():
		return
	var tween: Tween = _block_tweens[index]
	if tween and tween.is_running():
		tween.kill()
	_block_tweens[index] = null
	block_animating[index] = false

## 批量设置块颜色（直接）。
func set_blocks_colors(colors: PackedColorArray) -> void:
	var count: int = min(colors.size(), blocks.size())
	for i in range(count):
		set_block_color(i, colors[i])

## 清除所有块。
func clear_blocks() -> void:
	for block in blocks:
		block.queue_free()
	blocks.clear()
	block_base_colors.clear()
	block_animating.clear()
	block_base_positions.clear()
	_block_tweens.clear()
	capacity = 0

## 更新数值标签。
func update_label_text(current: int, max: int) -> void:
	if value_label:
		value_label.text = "%d / %d" % [current, max]

## ----- 背景相关 -----
## 直接设置背景颜色（可选动画）。
func set_background_color(color: Color, animate: bool = false) -> void:
	_ensure_background_style()
	if animate:
		var tween: Tween = create_tween()
		tween.tween_property(_background_stylebox, ^"bg_color", color, blink_duration)
	else:
		_background_stylebox.bg_color = color

## 根据比例（0~1）设置背景颜色：满血时保持原色，空血时完全变黑。
func set_background_ratio(ratio: float, animate: bool = false) -> void:
	var clamped: float = clamp(ratio, 0.0, 1.0)
	var target_color: Color = base_bg_color.lerp(Color.BLACK, 1.0 - clamped)
	set_background_color(target_color, animate)

## ----- 内部辅助 -----
## 调整块数量（增删）。
func _adjust_blocks(target_max: int) -> void:
	var current: int = blocks.size()
	if target_max > current:
		for i in range(current, target_max):
			var block: Panel = template.duplicate() as Panel
			block.visible = true
			var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
			block.add_theme_stylebox_override(&"panel", stylebox)
			fill_background.add_child(block)
			blocks.append(block)
			stylebox.bg_color = Color.TRANSPARENT
			block_base_colors.append(Color.TRANSPARENT)
			block_animating.append(false)
			block_base_positions.append(Vector2.ZERO)
			_block_tweens.append(null)
	elif target_max < current:
		for i in range(target_max, current):
			var block: Panel = blocks.pop_back()
			var idx: int = blocks.size()
			_cancel_block_animation(idx)
			block.queue_free()
			block_base_colors.pop_back()
			block_animating.pop_back()
			block_base_positions.pop_back()
			_block_tweens.pop_back()

## 重新布局所有块，存储基础位置。
func _layout_blocks() -> void:
	if capacity <= 0 or not fill_background:
		return
	var total_width: float = fill_background.size.x
	var total_height: float = fill_background.size.y
	if total_width <= 0 or total_height <= 0:
		call_deferred(&"_layout_blocks")
		return
	var block_width: float = total_width / capacity
	var block_height: float = total_height * block_scale
	var y_offset: float = (total_height - block_height) / 2.0
	for i in range(blocks.size()):
		var block: Panel = blocks[i]
		var pos: Vector2 = Vector2(i * block_width, y_offset)
		block.size = Vector2(block_width * block_scale, block_height)
		block.position = pos
		block_base_positions[i] = pos

## 确保背景样式存在并缓存原色。
func _ensure_background_style() -> void:
	if _background_stylebox:
		return
	var style: StyleBoxFlat = fill_background.get_theme_stylebox(&"panel") as StyleBoxFlat
	if not style:
		style = StyleBoxFlat.new()
		style.bg_color = Color.WHITE
		fill_background.add_theme_stylebox_override(&"panel", style)
	_background_stylebox = style
	if base_bg_color == Color.WHITE:
		base_bg_color = _background_stylebox.bg_color
