extends AreaFace

enum Mode { AUTO, MANUAL }
@export var mode: Mode = Mode.AUTO

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
var _current_player: RenderItem = null
var _cached_player_id: int = -1

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
	if mode == Mode.AUTO:
		target_area.local_player_received.connect(_on_local_player_received)
		if target_area.local_player:
			_on_local_player_received(target_area.local_player)
	# 手动模式下不做任何自动连接

func _on_local_player_received(local_player: RenderItem) -> void:
	set_player(local_player)

func set_player(player: RenderItem) -> void:
	if _current_player == player:
		return
	if _current_player:
		if _current_player.data_requested.is_connected(_on_player_data_requested):
			_current_player.data_requested.disconnect(_on_player_data_requested)
		_current_player = null
		_cached_player_id = -1
	_current_player = player
	if _current_player and _current_player.data is PlayerPack:
		if not _current_player.data_requested.is_connected(_on_player_data_requested):
			_current_player.data_requested.connect(_on_player_data_requested)
		_cached_player_id = _current_player.get_id()
		_update_cached_stats(_current_player.data)
	else:
		_clear_display()
		_cached_hp_max = 0
		_cached_hp_current = 0
		_cached_mp_max = 0
		_cached_mp_current = 0
		_cached_ap_current = 0
		_cached_modified_init_ap = 0
		_cached_player_id = 0

func _on_player_data_requested(player: RenderItem) -> void:
	if player == _current_player and player and player.data is PlayerPack:
		_update_cached_stats(player.data)

func _update_cached_stats(player_data: PlayerPack) -> void:
	var old_hp: int = _cached_hp_current
	var old_mp: int = _cached_mp_current
	var old_hp_max: int = _cached_hp_max
	var old_mp_max: int = _cached_mp_max
	var old_ap: int = _cached_ap_current
	var old_init_ap: int = _cached_modified_init_ap

	_cached_hp_max = player_data.modified_HP_max
	_cached_hp_current = player_data.HP
	_cached_mp_max = player_data.modified_MP_max
	_cached_mp_current = player_data.MP
	_cached_ap_current = player_data.AP
	_cached_modified_init_ap = player_data.modified_init_AP

	# 传入原始值（可能为负），但在动画内部会进行钳位处理
	if _cached_hp_max != old_hp_max or _cached_hp_current != old_hp:
		_apply_hp_animation(old_hp_max, old_hp, _cached_hp_max, _cached_hp_current)
		hp_label.text = "%d / %d" % [_cached_hp_current, _cached_hp_max]
	if _cached_mp_max != old_mp_max or _cached_mp_current != old_mp:
		_apply_mp_animation(old_mp_max, old_mp, _cached_mp_max, _cached_mp_current)
	if _cached_ap_current != old_ap or _cached_modified_init_ap != old_init_ap:
		_update_ap_display()

	var hp_damage: int = max(0, old_hp - _cached_hp_current)
	var mp_damage: int = max(0, old_mp - _cached_mp_current)
	if hp_damage > 0 or mp_damage > 0:
		_trigger_damage_event(hp_damage, mp_damage)

func _clear_display() -> void:
	hp_label.text = "0 / 0"
	for block in _hp_blocks:
		block.queue_free()
	_hp_blocks.clear()
	for unit in _mp_units:
		unit.queue_free()
	_mp_units.clear()
	ap_label.text = "X 0"

# ==================== HP 动画（修复负数索引问题）====================
func _apply_hp_animation(old_max: int, old_cur: int, new_max: int, new_cur: int) -> void:
	# 钳位当前值用于渲染（避免负数索引）
	var clamped_new_cur: int = max(0, new_cur)
	var clamped_old_cur: int = max(0, old_cur)

	_adjust_hp_bar_capacity(new_max, clamped_new_cur)  # 传入钳位后的当前值

	if new_max > old_max:
		for i in range(old_max, new_max):
			var block: Panel = _hp_blocks[i]
			var target: Color = COLOR_HP_CURRENT if i < clamped_new_cur else COLOR_HP_LOST
			var transparent: Color = Color(target.r, target.g, target.b, 0.0)
			_start_hp_block_blink(block, transparent, target)

		if old_cur != new_cur:
			# 动画范围需要钳位起始和结束
			var start: int = max(0, min(clamped_old_cur, clamped_new_cur))
			var end: int = max(0, max(clamped_old_cur, clamped_new_cur) - 1)
			_animate_hp_range(start, end, new_cur < old_cur, old_max)

	elif new_max < old_max:
		for i in range(new_max):
			var block: Panel = _hp_blocks[i]
			var target: Color = COLOR_HP_CURRENT if i < clamped_new_cur else COLOR_HP_LOST
			_start_hp_block_special_blink(block, target)

		if old_cur != new_cur:
			var start: int = max(0, min(clamped_old_cur, clamped_new_cur))
			var end: int = max(0, max(clamped_old_cur, clamped_new_cur) - 1)
			_animate_hp_range(start, end, new_cur < old_cur, new_max)

	else:  # max 相等
		if old_cur != new_cur:
			var start: int = max(0, min(clamped_old_cur, clamped_new_cur))
			var end: int = max(0, max(clamped_old_cur, clamped_new_cur) - 1)
			_animate_hp_range(start, end, new_cur < old_cur, new_max)

func _animate_hp_range(start: int, end: int, is_decrease: bool, limit: int) -> void:
	# 确保 start 不小于 0（已由调用方保证），但额外保护
	start = max(0, start)
	if start > end:
		return
	for i in range(start, end + 1):
		if i >= limit:
			continue
		var block: Panel = _hp_blocks[i]
		var from_color: Color = COLOR_HP_CURRENT if is_decrease else COLOR_HP_LOST
		var to_color: Color = COLOR_HP_LOST if is_decrease else COLOR_HP_CURRENT
		_start_hp_block_blink(block, from_color, to_color)

func _adjust_hp_bar_capacity(target_max: int, new_cur: int) -> void:
	# new_cur 已经钳位为非负数
	var current: int = _hp_blocks.size()
	if target_max > current:
		for i in range(current, target_max):
			var block: Panel = hp_fill_template.duplicate() as Panel
			block.visible = true
			var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
			block.add_theme_stylebox_override(&"panel", stylebox)
			hp_fill_background.add_child(block)
			_hp_blocks.append(block)
			var target_color: Color = COLOR_HP_CURRENT if i < new_cur else COLOR_HP_LOST
			target_color.a = 0.0
			stylebox.bg_color = target_color
		_relayout_hp_blocks()
	elif target_max < current:
		for i in range(target_max, current):
			var block: Panel = _hp_blocks.pop_back()
			block.queue_free()
		_relayout_hp_blocks()

func _relayout_hp_blocks() -> void:
	if _cached_hp_max <= 0:
		return
	var block_width: float = hp_fill_background.size.x / _cached_hp_max
	for i in range(_hp_blocks.size()):
		var block: Panel = _hp_blocks[i]
		block.size = Vector2(block_width * 0.8, hp_fill_background.size.y * 0.8)
		block.position = Vector2(i * block_width, 0)

func _start_hp_block_blink(block: Panel, from_color: Color, to_color: Color) -> void:
	var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel") as StyleBoxFlat
	stylebox.bg_color = from_color
	UIAnimationUtils.blink_stylebox_bg_color(block, from_color, to_color, 2, 0.1)

func _start_hp_block_special_blink(block: Panel, target_color: Color) -> void:
	var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel") as StyleBoxFlat
	var start_color: Color = stylebox.bg_color
	var transparent: Color = Color(start_color.r, start_color.g, start_color.b, 0.0)
	var tween: Tween = create_tween()
	tween.tween_property(stylebox, ^"bg_color", transparent, 0.1)
	tween.tween_property(stylebox, ^"bg_color", target_color, 0.1)

# ==================== MP 动画（修复负数索引问题）====================
func _apply_mp_animation(old_max: int, old_cur: int, new_max: int, new_cur: int) -> void:
	var clamped_new_cur: int = max(0, new_cur)
	var clamped_old_cur: int = max(0, old_cur)

	_ensure_mp_capacity(new_max)
	var dots: Array = _get_all_mp_dots()

	if new_max > old_max:
		for i in range(old_max, new_max):
			var dot: ColorRect = dots[i] as ColorRect
			var target: Color = COLOR_MP_CURRENT if i < clamped_new_cur else COLOR_MP_LOST
			var transparent: Color = Color(target.r, target.g, target.b, 0.0)
			_start_mp_dot_blink(dot, transparent, target)

		if old_cur != new_cur:
			var start: int = max(0, min(clamped_old_cur, clamped_new_cur))
			var end: int = max(0, max(clamped_old_cur, clamped_new_cur) - 1)
			_animate_mp_range(start, end, new_cur < old_cur, old_max)

	elif new_max < old_max:
		for i in range(new_max, old_max):
			var dot: ColorRect = dots[i] as ColorRect
			_start_mp_dot_fade_out(dot, i, new_max)

		if old_cur != new_cur:
			var start: int = max(0, min(clamped_old_cur, clamped_new_cur))
			var end: int = max(0, max(clamped_old_cur, clamped_new_cur) - 1)
			_animate_mp_range(start, end, new_cur < old_cur, new_max)

	else:
		if old_cur != new_cur:
			var start: int = max(0, min(clamped_old_cur, clamped_new_cur))
			var end: int = max(0, max(clamped_old_cur, clamped_new_cur) - 1)
			_animate_mp_range(start, end, new_cur < old_cur, new_max)

func _animate_mp_range(start: int, end: int, is_decrease: bool, limit: int) -> void:
	start = max(0, start)
	if start > end:
		return
	var dots: Array = _get_all_mp_dots()
	for i in range(start, end + 1):
		if i >= limit:
			continue
		var dot: ColorRect = dots[i] as ColorRect
		var from_color: Color = COLOR_MP_CURRENT if is_decrease else COLOR_MP_LOST
		var to_color: Color = COLOR_MP_LOST if is_decrease else COLOR_MP_CURRENT
		_start_mp_dot_blink(dot, from_color, to_color)

func _ensure_mp_capacity(target_max: int) -> void:
	var needed: int = ceili(float(target_max) / 4.0)
	while _mp_units.size() < needed:
		var unit: Control = mp_unit_template.duplicate() as Control
		unit.visible = true
		var container: Control = unit.get_child(0) as Control
		if container:
			for dot in container.get_children():
				var color_dot: ColorRect = dot as ColorRect
				color_dot.color = Color(COLOR_MP_LOST.r, COLOR_MP_LOST.g, COLOR_MP_LOST.b, 0.0)
				color_dot.visible = true
		mp_container.add_child(unit)
		_mp_units.append(unit)

func _get_all_mp_dots() -> Array[ColorRect]:
	var dots: Array[ColorRect] = []
	for unit in _mp_units:
		var container: Control = unit.get_child(0) as Control
		if container:
			for dot in container.get_children():
				dots.append(dot as ColorRect)
	return dots

func _start_mp_dot_blink(dot: ColorRect, from_color: Color, to_color: Color) -> void:
	dot.color = from_color
	UIAnimationUtils.blink_color(dot, from_color, to_color, 2, 0.1)

func _start_mp_dot_fade_out(dot: ColorRect, dot_index: int, new_max: int) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(dot, ^"color", Color.TRANSPARENT, 0.2)
	tween.finished.connect(func():
		var unit: Control = _find_unit_of_dot(dot)
		if not unit:
			return
		var container: Control = unit.get_child(0) as Control
		if not container:
			return
		var any_visible: bool = false
		var all_dots: Array[ColorRect] = _get_all_mp_dots()
		for d in container.get_children():
			var idx: int = all_dots.find(d)
			if idx != -1 and idx < new_max:
				any_visible = true
				break
		if not any_visible:
			unit.visible = false
	, CONNECT_ONE_SHOT)

func _find_unit_of_dot(dot: ColorRect) -> Control:
	for unit in _mp_units:
		var container: Control = unit.get_child(0) as Control
		if container and dot in container.get_children():
			return unit
	return null

# ==================== 伤害事件发送（保持不变）====================
func _trigger_damage_event(hp_damage: int, mp_damage: int) -> void:
	if _cached_player_id == -1:
		return
	var area: RenderArea = render_context.get_render_area(RenderArea.DefaultArea.PLAYERS)
	if area:
		var event: RenderEvent = RenderEvent.new().set_type(RenderEvent.DefaultType.DAMAGED)
		event.config[&"player_id"] = _cached_player_id
		event.config[&"hp_damage"] = hp_damage
		event.config[&"mp_damage"] = mp_damage
		area.tween_update(event)

# ==================== AP 更新（保持不变）====================
func _update_ap_display() -> void:
	ap_label.text = "%d / %d" % [_cached_ap_current, _cached_modified_init_ap]
