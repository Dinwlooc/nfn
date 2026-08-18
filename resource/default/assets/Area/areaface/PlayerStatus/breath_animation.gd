## 呼吸动画控制器（纯逻辑），不依赖节点树。
extends RefCounted

const BlockIndicator = preload("block_indicator.gd")

## 亮度偏移幅度
var amplitude: float = 0.2
## 相位更新间隔（帧）
var frame_interval: int = 4
## 块间相位偏移
var phase_offset: int = 4

var _indicator: BlockIndicator = null
var _active: bool = false
var _sine_table: PackedFloat64Array = PackedFloat64Array()
var _global_phase_index: int = 0

const TABLE_SIZE: int = 64
const PHASE_INCREMENT: int = 1
const MASK: int = TABLE_SIZE - 1

func _init() -> void:
	_generate_sine_table()

## 绑定目标指示器
func bind_indicator(indicator: BlockIndicator) -> void:
	_indicator = indicator

## 启用/禁用
func set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	if not active and _indicator:
		# 恢复所有块为基础颜色
		for i in range(_indicator.blocks.size()):
			if _indicator.block_animating[i]:
				continue
			var base_color: Color = _indicator.block_base_colors[i]
			var block: Panel = _indicator.blocks[i]
			var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel") as StyleBoxFlat
			stylebox.bg_color = base_color

## 每帧更新（由外部调用）
func update() -> void:
	if not _active or not _indicator or _indicator.blocks.is_empty():
		return
	if Engine.get_process_frames() % frame_interval != 0:
		return
	_global_phase_index = (_global_phase_index + PHASE_INCREMENT) & MASK
	for i in range(_indicator.blocks.size()):
		if _indicator.block_animating[i]:
			continue
		var phase: int = (_global_phase_index + i * phase_offset) & MASK
		var brightness: float = 1.0 + amplitude * _sine_table[phase]
		var base_color: Color = _indicator.block_base_colors[i]
		var new_color: Color = Color(
			clamp(base_color.r * brightness, 0.0, 1.0),
			clamp(base_color.g * brightness, 0.0, 1.0),
			clamp(base_color.b * brightness, 0.0, 1.0),
			base_color.a
		)
		var block: Panel = _indicator.blocks[i]
		var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel") as StyleBoxFlat
		stylebox.bg_color = new_color

func _generate_sine_table() -> void:
	_sine_table.resize(TABLE_SIZE)
	for i in range(TABLE_SIZE):
		var angle: float = 2.0 * PI * float(i) / float(TABLE_SIZE)
		_sine_table[i] = sin(angle)
