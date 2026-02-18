extends AreaFace

# --- 节点引用 ---
@onready var hp_bar: Control = $HPBar
@onready var hp_fill_background: Panel = $HPBar/HPFillBackGound
@onready var hp_fill_template: Panel = $HPBar/HPFillBackGound/HPFill # 作为模板的单个HP块
@onready var hp_label: Label = $HPBar/HPLabel
@onready var mp_container: HBoxContainer = $MPContainer
@onready var mp_unit_template: Control = $MPContainer/MPUnit # 作为模板的MP单元
@onready var ap_container: Control = $APContainer
@onready var ap_icon: Control = $APContainer/APIcon
@onready var ap_label: Label = $APContainer/APLabel
# --- 缓存变量 ---
var _cached_hp_max: int = 0
var _cached_hp_current: int = 0
var _cached_mp_max: int = 0
var _cached_mp_current: int = 0
var _cached_ap_current: int = 0
var _cached_modified_init_ap: int = 0
var _hp_blocks: Array[Panel] = []
var _mp_units: Array[Control] = []
const COLOR_HP_CURRENT: Color = Color(0.99, 0.1, 0.0) #红色
const COLOR_HP_LOST: Color = Color(0.5, 0.5, 0.5)  # 灰色
const COLOR_MP_CURRENT: Color = Color(0, 1.0, 1.0) # 天蓝色
const COLOR_MP_LOST: Color = Color(0.2, 0.2, 0.2)    # 灰色


func _ready() -> void:
	request_area(RenderArea.DefaultArea.PLAYERS)
	hp_fill_template.visible = false
	if mp_unit_template:
		mp_unit_template.visible = false

func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	if target_area is RenderAreaPlayers:
		target_area.local_player_received.connect(_on_local_player_received)
		if target_area.local_player:
			_on_local_player_received(target_area.local_player)

func _on_local_player_received(local_player: RenderItem) -> void:
	if local_player and local_player.data is PlayerPack:
		local_player.data_requested.connect(_on_local_player_data_request)
		_update_cached_stats(local_player.data)
	else:
		_clear_display()
		_cached_hp_max = 0
		_cached_hp_current = 0
		_cached_mp_max = 0
		_cached_mp_current = 0
		_cached_ap_current = 0
		_cached_modified_init_ap = 0

func _on_local_player_data_request(local_player: RenderItem)->void:
	if local_player and local_player.data is PlayerPack:
		_update_cached_stats(local_player.data)

func _update_cached_stats(player_data: PlayerPack) -> void:
	var old_hp_max = _cached_hp_max
	var old_hp_current = _cached_hp_current
	var old_mp_max = _cached_mp_max
	var old_mp_current = _cached_mp_current
	var old_ap_current = _cached_ap_current
	var old_modified_init_ap = _cached_modified_init_ap
	# 更新缓存
	_cached_hp_max = player_data.modified_HP_max
	_cached_hp_current = player_data.HP
	_cached_mp_max = player_data.modified_MP_max
	_cached_mp_current = player_data.MP
	_cached_ap_current = player_data.AP
	_cached_modified_init_ap = player_data.modified_init_AP
	# --- HP 处理 ---
	if _cached_hp_max != old_hp_max:
		_adjust_hp_bar_capacity()
		_update_hp_colors_full()      # 数量变化，全量更新颜色
	elif _cached_hp_current != old_hp_current:
		_update_hp_colors_range(old_hp_current, _cached_hp_current)
	if _cached_hp_max != old_hp_max or _cached_hp_current != old_hp_current:
		hp_label.text = "%d / %d" % [_cached_hp_current, _cached_hp_max]
	# --- MP 处理 ---
	if _cached_mp_max != old_mp_max:
		_adjust_mp_bar_capacity()
		_adjust_mp_dots_visibility()   # 新增
		_update_mp_colors_full()
	elif _cached_mp_current != old_mp_current:
		_update_mp_colors_range(old_mp_current, _cached_mp_current)
	# --- AP 处理 ---
	if _cached_ap_current != old_ap_current or _cached_modified_init_ap != old_modified_init_ap:
		_update_ap_display()

func _clear_display() -> void:
	hp_label.text = "0 / 0"
	for block in _hp_blocks:
		block.queue_free()
	_hp_blocks.clear()
	for unit in _mp_units:
		unit.queue_free()
	_mp_units.clear()
	ap_label.text = "X 0"

# ------------------------------------------------------------------------------
# HP 条相关
# ------------------------------------------------------------------------------
func _adjust_hp_bar_capacity() -> void:
	var target_count = _cached_hp_max
	var current_count = _hp_blocks.size()
	if target_count > current_count:
		if _cached_hp_max <= 0: return
		for i in range(current_count, target_count):
			var new_block: Panel = hp_fill_template.duplicate()
			new_block.visible = true
			var stylebox = new_block.get_theme_stylebox(&"panel").duplicate()
			new_block.add_theme_stylebox_override(&"panel", stylebox)
			hp_fill_background.add_child(new_block)
			_hp_blocks.append(new_block)
		_relayout_hp_blocks()
	elif target_count < current_count:
		# 移除多余的块
		for i in range(target_count, current_count):
			var block_to_remove = _hp_blocks.back()
			_hp_blocks.pop_back()
			block_to_remove.queue_free()
		_relayout_hp_blocks()

func _relayout_hp_blocks() -> void:
	if _cached_hp_max <= 0: return
	var block_width = hp_fill_background.size.x / _cached_hp_max
	for i in range(_hp_blocks.size()):
		var block = _hp_blocks[i]
		block.size = Vector2(block_width, hp_fill_background.size.y)
		block.position = Vector2(i * block_width, 0)

func _update_hp_colors_full() -> void:
	if _cached_hp_max <= 0: return
	for i in range(_cached_hp_max):
		var block = _hp_blocks[i]
		var stylebox = block.get_theme_stylebox(&"panel") as StyleBoxFlat
		stylebox.bg_color = COLOR_HP_CURRENT if i < _cached_hp_current else COLOR_HP_LOST

func _update_hp_colors_range(old_val: int, new_val: int) -> void:
	if old_val == new_val:
		return
	var start = min(old_val, new_val)
	var end = max(old_val, new_val) - 1
	var color = COLOR_HP_CURRENT if new_val > old_val else COLOR_HP_LOST
	for i in range(start, end + 1):
		var block = _hp_blocks[i]
		var stylebox = block.get_theme_stylebox(&"panel") as StyleBoxFlat
		stylebox.bg_color = color

# ------------------------------------------------------------------------------
# MP 条相关
# ------------------------------------------------------------------------------
func _adjust_mp_dots_visibility() -> void:
	var total_points = 0
	for unit in _mp_units:
		var dots_container = unit.get_child(0)
		if not dots_container:
			continue
		for dot in dots_container.get_children():
			if total_points < _cached_mp_max:
				dot.visible = true
				total_points += 1
			else:
				dot.visible = false

func _adjust_mp_bar_capacity() -> void:
	var target_count = ceili(float(_cached_mp_max) / 4.0)
	var current_count = _mp_units.size()
	if target_count > current_count:
		if _cached_mp_max <= 0: return
		for i in range(target_count - current_count):
			var new_unit = mp_unit_template.duplicate()
			new_unit.visible = true
			var dots_container = new_unit.get_child(0)
			if dots_container:
				var sub_dots = dots_container.get_children()
				if sub_dots.size() >= 4:
					for j in range(4):
						sub_dots[j].visible = true
						sub_dots[j].color = COLOR_MP_LOST # 初始为lost状态
			mp_container.add_child(new_unit)
			_mp_units.append(new_unit)
	elif target_count < current_count:
		for i in range(target_count, current_count):
			var unit_to_remove = _mp_units.back()
			_mp_units.pop_back()
			unit_to_remove.queue_free()

func _update_mp_colors_full() -> void:
	if _cached_mp_max <= 0: return
	var current_mp_index = 0
	for unit in _mp_units:
		var dots_container = unit.get_child(0)
		if not dots_container: continue
		for dot in dots_container.get_children():
			if not dot.visible: continue
			dot.color = COLOR_MP_CURRENT if current_mp_index < _cached_mp_current else COLOR_MP_LOST
			current_mp_index += 1
			if current_mp_index >= _cached_mp_max:
				break
		if current_mp_index >= _cached_mp_max:
			break

func _update_mp_colors_range(old_val: int, new_val: int) -> void:
	if old_val == new_val:
		return
	var start = min(old_val, new_val)
	var end = max(old_val, new_val) - 1
	var color = COLOR_MP_CURRENT if new_val > old_val else COLOR_MP_LOST
	for i in range(start, end + 1):
		var unit_idx = i / 4
		var dot_idx = i % 4
		if unit_idx < _mp_units.size():
			var unit = _mp_units[unit_idx]
			var dots_container = unit.get_child(0)
			if dots_container and dot_idx < dots_container.get_child_count():
				var dot = dots_container.get_child(dot_idx)
				dot.color = color
# ------------------------------------------------------------------------------
# AP 显示
# ------------------------------------------------------------------------------
func _update_ap_display() -> void:
	ap_label.text = "%d / %d" % [_cached_ap_current, _cached_modified_init_ap]
