## 颤动动画控制器（纯逻辑），计算每个块的垂直偏移，通过信号通知外部。
extends RefCounted

## 信号：偏移变化（索引，偏移向量）
signal offset_updated(index: int, offset: Vector2)

## 最小偏移（像素）
var min_offset: float = 0.1
## 基础最大偏移（像素），实际最大偏移会动态调整
var base_max_offset: float = 0.05
## 最大偏移倍数（血量越低，偏移越大）
var max_offset_multiplier: float = 64.0
## 基础更新间隔（帧），血量满时使用
var base_update_interval: int = 24
## 最小更新间隔（帧），血量最低时使用
var min_update_interval: int = 3
## 块间相位偏移
var phase_offset: int = 1

var _active: bool = false
var _block_count: int = 0
var _current_max_offset: float = 2.6
var _current_update_interval: int = 12
var _update_counter: int = 0
const CYCLE_UPDATES: int = 10
const ACTIVE_UPDATES: int = 10

## 设置块数量
func set_block_count(count: int) -> void:
	_block_count = count

## 启用/禁用
func set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	_update_counter = 0
	if not active:
		# 通知外部恢复所有块偏移为零
		for i in range(_block_count):
			offset_updated.emit(i, Vector2.ZERO)

## 根据血量比例更新幅度和频率参数
func update_amplitude_by_hp(hp: int, max_hp: int) -> void:
	if max_hp <= 0:
		_current_max_offset = 0.0
		_current_update_interval = base_update_interval
		return
	var ratio: float = clamp(float(hp) / float(max_hp), 0.0, 1.0)
	_current_max_offset = base_max_offset * (1.0 + (1.0 - ratio) * (max_offset_multiplier - 1.0))
	_current_update_interval = int(lerp(float(min_update_interval), float(base_update_interval), ratio))
	_current_update_interval = clamp(_current_update_interval, min_update_interval, base_update_interval)

## 每帧更新（由外部调用）
func update() -> void:
	if not _active or _block_count <= 0 or _current_max_offset <= 0.0:
		return
	if Engine.get_process_frames() % _current_update_interval != 0:
		return
	_update_counter = (_update_counter + 1) % CYCLE_UPDATES
	var amplitude: float = randf_range(min_offset, _current_max_offset)
	for i in range(_block_count):
		var state_idx: int = (_update_counter + i * phase_offset) % CYCLE_UPDATES
		var offset_y: float = 0.0
		if state_idx < ACTIVE_UPDATES:
			match state_idx:
				0, 1:
					offset_y = -amplitude
				2, 3, 6, 7:
					offset_y = 0.0
				4, 5:
					offset_y = amplitude
		offset_updated.emit(i, Vector2(0, offset_y))
