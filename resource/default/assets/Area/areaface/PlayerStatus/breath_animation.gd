## 呼吸动画控制器（纯逻辑），仅计算每个块的亮度变化，通过信号通知外部。
extends RefCounted

## 信号：亮度变化（索引，亮度倍数）
signal brightness_updated(index: int, brightness: float)

## 亮度偏移幅度（0~1）
var amplitude: float = 0.2
## 相位更新间隔（帧）
var frame_interval: int = 4
## 块间相位偏移（整数）
var phase_offset: int = 4

var _active: bool = false
var _sine_table: PackedFloat64Array = PackedFloat64Array()
var _global_phase_index: int = 0
var _block_count: int = 0

const TABLE_SIZE: int = 64
const PHASE_INCREMENT: int = 1
const MASK: int = TABLE_SIZE - 1

func _init() -> void:
	_generate_sine_table()

## 设置块数量（与指示器容量一致）
func set_block_count(count: int) -> void:
	_block_count = count

## 启用/禁用
func set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	if not active:
		# 通知外部恢复所有块为基准亮度（1.0）
		for i in range(_block_count):
			brightness_updated.emit(i, 1.0)

## 每帧更新（由外部调用）
func update() -> void:
	if not _active or _block_count <= 0:
		return
	if Engine.get_process_frames() % frame_interval != 0:
		return
	_global_phase_index = (_global_phase_index + PHASE_INCREMENT) & MASK
	for i in range(_block_count):
		var phase: int = (_global_phase_index + i * phase_offset) & MASK
		var brightness: float = 1.0 + amplitude * _sine_table[phase]
		brightness_updated.emit(i, brightness)

func _generate_sine_table() -> void:
	_sine_table.resize(TABLE_SIZE)
	for i in range(TABLE_SIZE):
		var angle: float = 2.0 * PI * float(i) / float(TABLE_SIZE)
		_sine_table[i] = sin(angle)
