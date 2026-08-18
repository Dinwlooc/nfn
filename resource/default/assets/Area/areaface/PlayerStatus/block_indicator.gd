## 块指示器：管理一组块（Panel）的容量、布局和颜色/闪烁动画。
## 作为场景根节点，内部包含 FillBackground 和 Template 作为子节点。
## 可选包含 ValueLabel 用于显示数值（HP 使用），战意可省略。
extends Control
## 块相对于格子宽高的缩放系数。
@export var block_scale: float = 0.8
## 默认闪烁时长（秒）。
@export var blink_duration: float = 0.2
## 承载块的背景容器。
@onready var fill_background: Control = $FillBackground
## 块模板（隐藏）。
@onready var template: Panel = $Template
## 数值标签（可选，若不存在则忽略）。
@onready var value_label: Label = $ValueLabel

var _blocks: Array[Panel] = []  ## 当前所有块实例
var _capacity: int = 0          ## 当前容量（块数）

## 设置容量，调整块数量并重新布局。
func set_capacity(new_max: int) -> void:
	if new_max < 0:
		return
	_capacity = new_max
	_adjust_blocks(new_max)
	_layout_blocks()

## 设置单个块的颜色（可选动画）。
func set_block_color(index: int, color: Color, animate: bool = false) -> void:
	if index < 0 or index >= _blocks.size():
		return
	var block: Panel = _blocks[index]
	var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel") as StyleBoxFlat
	if animate:
		UIAnimationUtils.blink_stylebox_bg_color(block, stylebox.bg_color, color, blink_duration)
	else:
		stylebox.bg_color = color

## 批量设置块颜色（可选动画）。
func set_blocks_colors(colors: PackedColorArray, animate: bool = false) -> void:
	var count: int = min(colors.size(), _blocks.size())
	for i in range(count):
		set_block_color(i, colors[i], animate)

## 对单个块执行从起始颜色到目标颜色的闪烁。
func blink_block(index: int, from_color: Color, to_color: Color, duration: float = blink_duration) -> void:
	if index < 0 or index >= _blocks.size():
		return
	var block: Panel = _blocks[index]
	var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel") as StyleBoxFlat
	stylebox.bg_color = from_color
	UIAnimationUtils.blink_stylebox_bg_color(block, from_color, to_color, duration)

## 清除所有块。
func clear_blocks() -> void:
	for block in _blocks:
		block.queue_free()
	_blocks.clear()
	_capacity = 0

## 更新数值标签（如果存在）。
func update_label_text(current: int, max: int) -> void:
	if value_label:
		value_label.text = "%d / %d" % [current, max]

## 调整块数量（增删）。
func _adjust_blocks(target_max: int) -> void:
	var current: int = _blocks.size()
	if target_max > current:
		for i in range(current, target_max):
			var block: Panel = template.duplicate() as Panel
			block.visible = true
			var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
			block.add_theme_stylebox_override(&"panel", stylebox)
			fill_background.add_child(block)
			_blocks.append(block)
			stylebox.bg_color = Color.TRANSPARENT
	elif target_max < current:
		for i in range(target_max, current):
			var block: Panel = _blocks.pop_back()
			block.queue_free()

## 重新布局所有块。
func _layout_blocks() -> void:
	if _capacity <= 0 or not fill_background:
		return
	var total_width: float = fill_background.size.x
	var total_height: float = fill_background.size.y
	if total_width <= 0 or total_height <= 0:
		call_deferred(&"_layout_blocks")
		return
	var block_width: float = total_width / _capacity
	var block_height: float = total_height * block_scale
	var y_offset: float = (total_height - block_height) / 2.0
	for i in range(_blocks.size()):
		var block: Panel = _blocks[i]
		block.size = Vector2(block_width * block_scale, block_height)
		block.position = Vector2(i * block_width, y_offset)
