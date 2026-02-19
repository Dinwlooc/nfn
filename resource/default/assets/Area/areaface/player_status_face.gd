extends AreaFace

@onready var hp_bar: Control = $HPBar
@onready var hp_fill_background: Panel = $HPBar/HPFillBackGound
@onready var hp_fill_template: Panel = $HPBar/HPFillBackGound/HPFill
@onready var hp_label: Label = $HPBar/HPLabel
@onready var mp_container: HBoxContainer = $MPContainer
@onready var mp_unit_template: Control = $MPContainer/MPUnit
@onready var ap_container: Control = $APContainer
@onready var ap_icon: Control = $APContainer/APIcon
@onready var ap_label: Label = $APContainer/APLabel

var _cached_hp_max: int = 0
var _cached_hp_current: int = 0
var _cached_mp_max: int = 0
var _cached_mp_current: int = 0
var _cached_ap_current: int = 0
var _cached_modified_init_ap: int = 0
var _hp_blocks: Array[Panel] = []
var _mp_units: Array[Control] = []

const COLOR_HP_CURRENT: Color = Color(0.99, 0.1, 0.0,0.7)
const COLOR_HP_LOST: Color = Color(0.5, 0.5, 0.5,0.7)
const COLOR_MP_CURRENT: Color = Color(0, 1.0, 1.0,0.7)
const COLOR_MP_LOST: Color = Color(0.2, 0.2, 0.2,0.7)

func _ready() -> void:
	request_area(RenderArea.DefaultArea.PLAYERS)
	hp_fill_template.visible = false
	if mp_unit_template:
		mp_unit_template.visible = false

func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	if not (target_area is RenderAreaPlayers):
		return
	target_area.local_player_received.connect(_on_local_player_received)
	if target_area.local_player:
		_on_local_player_received(target_area.local_player)

func _on_local_player_received(local_player: RenderItem) -> void:
	if not (local_player and local_player.data is PlayerPack):
		_clear_display()
		_cached_hp_max = 0
		_cached_hp_current = 0
		_cached_mp_max = 0
		_cached_mp_current = 0
		_cached_ap_current = 0
		_cached_modified_init_ap = 0
		return
	local_player.data_requested.connect(_on_local_player_data_request)
	_update_cached_stats(local_player.data)

func _on_local_player_data_request(local_player: RenderItem) -> void:
	if local_player and local_player.data is PlayerPack:
		_update_cached_stats(local_player.data)

func _update_cached_stats(player_data: PlayerPack) -> void:
	var old_hp_max = _cached_hp_max
	var old_hp_current = _cached_hp_current
	var old_mp_max = _cached_mp_max
	var old_mp_current = _cached_mp_current
	var old_ap_current = _cached_ap_current
	var old_modified_init_ap = _cached_modified_init_ap

	_cached_hp_max = player_data.modified_HP_max
	_cached_hp_current = player_data.HP
	_cached_mp_max = player_data.modified_MP_max
	_cached_mp_current = player_data.MP
	_cached_ap_current = player_data.AP
	_cached_modified_init_ap = player_data.modified_init_AP

	if _cached_hp_max != old_hp_max or _cached_hp_current != old_hp_current:
		_apply_hp_animation(old_hp_max, old_hp_current, _cached_hp_max, _cached_hp_current)
		hp_label.text = "%d / %d" % [_cached_hp_current, _cached_hp_max]
	if _cached_mp_max != old_mp_max or _cached_mp_current != old_mp_current:
		_apply_mp_animation(old_mp_max, old_mp_current, _cached_mp_max, _cached_mp_current)
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

func _apply_hp_animation(old_max: int, old_cur: int, new_max: int, new_cur: int) -> void:
	_adjust_hp_bar_capacity(new_max, new_cur)

	if new_max > old_max:
		for i in range(old_max, new_max):
			var block = _hp_blocks[i]
			var target = COLOR_HP_CURRENT if i < new_cur else COLOR_HP_LOST
			var transparent = Color(target.r, target.g, target.b, 0.0)
			_start_hp_block_blink(block, transparent, target)
		if old_cur != new_cur:
			_animate_hp_range(min(old_cur, new_cur), max(old_cur, new_cur) - 1, new_cur < old_cur, old_max)
	elif new_max < old_max:
		for i in range(new_max):
			var block = _hp_blocks[i]
			var target = COLOR_HP_CURRENT if i < new_cur else COLOR_HP_LOST
			_start_hp_block_special_blink(block, target)
		if old_cur != new_cur:
			_animate_hp_range(min(old_cur, new_cur), max(old_cur, new_cur) - 1, new_cur < old_cur, new_max)
	else:
		if old_cur != new_cur:
			_animate_hp_range(min(old_cur, new_cur), max(old_cur, new_cur) - 1, new_cur < old_cur, new_max)

	if new_cur < old_cur:
		_trigger_damage_event(old_cur - new_cur)

func _animate_hp_range(start: int, end: int, is_decrease: bool, limit: int) -> void:
	for i in range(start, end + 1):
		if i >= limit:
			continue
		var block = _hp_blocks[i]
		var from_color = COLOR_HP_CURRENT if is_decrease else COLOR_HP_LOST
		var to_color = COLOR_HP_LOST if is_decrease else COLOR_HP_CURRENT
		_start_hp_block_blink(block, from_color, to_color)

func _adjust_hp_bar_capacity(target_max: int, new_cur: int) -> void:
	var current = _hp_blocks.size()
	if target_max > current:
		for i in range(current, target_max):
			var block: Panel = hp_fill_template.duplicate()
			block.visible = true
			var stylebox = block.get_theme_stylebox(&"panel").duplicate()
			block.add_theme_stylebox_override(&"panel", stylebox)
			hp_fill_background.add_child(block)
			_hp_blocks.append(block)
			var target_color = COLOR_HP_CURRENT if i < new_cur else COLOR_HP_LOST
			target_color.a = 0.0
			stylebox.bg_color = target_color
		_relayout_hp_blocks()
	elif target_max < current:
		for i in range(target_max, current):
			var block = _hp_blocks.pop_back()
			block.queue_free()
		_relayout_hp_blocks()

func _relayout_hp_blocks() -> void:
	if _cached_hp_max <= 0:
		return
	var block_width = hp_fill_background.size.x / _cached_hp_max
	for i in range(_hp_blocks.size()):
		var block = _hp_blocks[i]
		block.size = Vector2(block_width*0.8, hp_fill_background.size.y*0.8)
		block.position = Vector2(i * block_width, 0)

func _start_hp_block_blink(block: Panel, from_color: Color, to_color: Color) -> void:
	var stylebox = block.get_theme_stylebox(&"panel") as StyleBoxFlat
	stylebox.bg_color = from_color
	UIAnimationUtils.blink_stylebox_bg_color(block, from_color, to_color, 2, 0.1)

func _start_hp_block_special_blink(block: Panel, target_color: Color) -> void:
	var stylebox = block.get_theme_stylebox(&"panel") as StyleBoxFlat
	var start_color = stylebox.bg_color
	var transparent = Color(start_color.r, start_color.g, start_color.b, 0.0)
	var tween = create_tween()
	tween.tween_property(stylebox, ^"bg_color", transparent, 0.1)
	tween.tween_property(stylebox, ^"bg_color", target_color, 0.1)

func _apply_mp_animation(old_max: int, old_cur: int, new_max: int, new_cur: int) -> void:
	_ensure_mp_capacity(new_max)
	var dots = _get_all_mp_dots()

	if new_max > old_max:
		for i in range(old_max, new_max):
			var dot = dots[i]
			var target = COLOR_MP_CURRENT if i < new_cur else COLOR_MP_LOST
			var transparent = Color(target.r, target.g, target.b, 0.0)
			_start_mp_dot_blink(dot, transparent, target)
		if old_cur != new_cur:
			_animate_mp_range(min(old_cur, new_cur), max(old_cur, new_cur) - 1, new_cur < old_cur, old_max)
	elif new_max < old_max:
		for i in range(new_max, old_max):
			var dot = dots[i]
			_start_mp_dot_fade_out(dot, i, new_max)
		if old_cur != new_cur:
			_animate_mp_range(min(old_cur, new_cur), max(old_cur, new_cur) - 1, new_cur < old_cur, new_max)
	else:
		if old_cur != new_cur:
			_animate_mp_range(min(old_cur, new_cur), max(old_cur, new_cur) - 1, new_cur < old_cur, new_max)

func _animate_mp_range(start: int, end: int, is_decrease: bool, limit: int) -> void:
	var dots = _get_all_mp_dots()
	for i in range(start, end + 1):
		if i >= limit:
			continue
		var dot = dots[i]
		var from_color = COLOR_MP_CURRENT if is_decrease else COLOR_MP_LOST
		var to_color = COLOR_MP_LOST if is_decrease else COLOR_MP_CURRENT
		_start_mp_dot_blink(dot, from_color, to_color)

func _ensure_mp_capacity(target_max: int) -> void:
	var needed = ceili(float(target_max) / 4.0)
	while _mp_units.size() < needed:
		var unit = mp_unit_template.duplicate()
		unit.visible = true
		var container = unit.get_child(0)
		if container:
			for dot in container.get_children():
				dot.color = Color(COLOR_MP_LOST.r, COLOR_MP_LOST.g, COLOR_MP_LOST.b, 0.0)
				dot.visible = true
		mp_container.add_child(unit)
		_mp_units.append(unit)

func _get_all_mp_dots() -> Array:
	var dots = []
	for unit in _mp_units:
		var container = unit.get_child(0)
		if container:
			dots.append_array(container.get_children())
	return dots

func _start_mp_dot_blink(dot: ColorRect, from_color: Color, to_color: Color) -> void:
	dot.color = from_color
	UIAnimationUtils.blink_color(dot, from_color, to_color, 2, 0.1)

func _start_mp_dot_fade_out(dot: ColorRect, dot_index: int, new_max: int) -> void:
	var tween = create_tween()
	tween.tween_property(dot, ^"color", Color.TRANSPARENT, 0.2)
	tween.finished.connect(func():
		var unit = _find_unit_of_dot(dot)
		if not unit:
			return
		var container = unit.get_child(0)
		if not container:
			return
		var any_visible = false
		var all_dots = _get_all_mp_dots()
		for d in container.get_children():
			var idx = all_dots.find(d)
			if idx != -1 and idx < new_max:
				any_visible = true
				break
		if not any_visible:
			unit.visible = false
	, CONNECT_ONE_SHOT)

func _find_unit_of_dot(dot: ColorRect) -> Control:
	for unit in _mp_units:
		var container = unit.get_child(0)
		if container and dot in container.get_children():
			return unit
	return null

func _trigger_damage_event(damage: int) -> void:
	var area = render_context.get_render_area(RenderArea.DefaultArea.PLAYERS)
	if area:
		var event = RenderEvent.new().set_type(RenderEvent.DefaultType.DAMAGED)
		event.config[&"damage"] = damage
		area.render_update(event)

func _update_ap_display() -> void:
	ap_label.text = "%d / %d" % [_cached_ap_current, _cached_modified_init_ap]
