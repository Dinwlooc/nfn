## 颤动动画控制器（纯逻辑），不依赖节点树。
## 竖向上下颤动，每帧间隔动态变化，根据血量比例调整频率。
## 所有块（包括已损格）均参与颤动。
extends RefCounted

const BlockIndicator = preload("block_indicator.gd")

## 最小偏移（像素）
var min_offset: float = 0.05
## 基础最大偏移（像素），实际最大偏移会根据血量动态变化
var base_max_offset: float = 0.1
## 最大偏移倍数（血量越低，最大偏移越接近此倍数 × base_max_offset）
var max_offset_multiplier: float = 64.0
## 当前实际最大偏移（由血量比例决定）
var current_max_offset: float = 2.6
## 基础更新间隔（帧），血量满时使用此间隔
var base_update_interval: int = 24
## 最小更新间隔（帧），血量最低时使用此间隔（即基础间隔的1/4）
var min_update_interval: int = 3
## 当前实际更新间隔（动态计算）
var current_update_interval: int = 12
## 块间相位偏移（用于错开各块状态）
var phase_offset: int = 1

var _indicator: BlockIndicator = null
var _active: bool = false
var _tremor_enabled: Array[bool] = []    # 每个块是否启用颤动（当前始终为 true）
var _tremor_offsets: Array[float] = []   # 每个块当前的 Y 偏移量
var _update_counter: int = 0              # 更新次数计数器（每次更新+1）

const CYCLE_UPDATES: int = 10            # 总更新点数（20 * 当前间隔 = 周期帧数）
const ACTIVE_UPDATES: int = 10            # 全部为活动状态（无静止）

## 绑定目标指示器
func bind_indicator(indicator: BlockIndicator) -> void:
	_indicator = indicator
	_ensure_arrays()
	_enable_all_blocks()

## 启用/禁用
func set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	_update_counter = 0
	if _active:
		_enable_all_blocks()
	else:
		if _indicator:
			_ensure_arrays()
			for i in range(_indicator.blocks.size()):
				if _tremor_offsets[i] == 0.0:
					continue
				_tremor_offsets[i] = 0.0
				_indicator.blocks[i].position = _indicator.block_base_positions[i]

## 更新颤动掩码（废弃，强制启用所有块）
func update_mask(_current_hp: int = 0) -> void:
	_enable_all_blocks()

## 根据当前血量和最大血量更新幅度和频率参数
func update_amplitude_by_hp(hp: int, max_hp: int) -> void:
	if max_hp <= 0:
		current_max_offset = 0.0
		current_update_interval = base_update_interval
		return
	var ratio: float = clamp(float(hp) / float(max_hp), 0.0, 1.0)
	# 更新幅度：血量越少，最大偏移越大
	current_max_offset = base_max_offset * (1.0 + (1.0 - ratio) * (max_offset_multiplier - 1.0))
	# 更新频率：血量越少，间隔越小（越快）
	current_update_interval = int(lerp(float(min_update_interval), float(base_update_interval), ratio))
	current_update_interval = clamp(current_update_interval, min_update_interval, base_update_interval)

## 每帧更新（由外部调用）
func update() -> void:
	if not _active or not _indicator or _indicator.blocks.is_empty():
		return
	if current_max_offset <= 0.0:
		return
	if Engine.get_process_frames() % current_update_interval != 0:
		return
	_ensure_arrays()
	_update_counter = (_update_counter + 1) % CYCLE_UPDATES
	var amplitude: float = randf_range(min_offset, current_max_offset)

	for i in range(_indicator.blocks.size()):
		if _indicator.block_animating[i]:
			if _tremor_offsets[i] != 0.0:
				_tremor_offsets[i] = 0.0
				_indicator.blocks[i].position = _indicator.block_base_positions[i]
			continue

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

		if _tremor_offsets[i] == offset_y:
			continue
		_tremor_offsets[i] = offset_y
		_indicator.blocks[i].position = _indicator.block_base_positions[i] + Vector2(0, offset_y)

func _enable_all_blocks() -> void:
	if not _indicator:
		return
	_ensure_arrays()
	for i in range(_indicator.blocks.size()):
		_tremor_enabled[i] = true

func _ensure_arrays() -> void:
	if not _indicator:
		return
	var block_count: int = _indicator.blocks.size()
	if _tremor_enabled.size() == block_count:
		return
	_tremor_enabled.resize(block_count)
	_tremor_offsets.resize(block_count)
	for i in range(block_count):
		_tremor_enabled[i] = false
		_tremor_offsets[i] = 0.0
