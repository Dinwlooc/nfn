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
@onready var mp_label: Label = $MPLabel

@onready var morale_level_label: Label = $MoraleBar/MoraleLevelLabel
@onready var morale_value_label: RichTextLabel = $MoraleBar/MoraleValueLabel
@onready var morale_bar: Control = $MoraleBar
@onready var morale_fill_background: Panel = $MoraleBar/MoraleFillBackground
@onready var morale_fill_template: Panel = $MoraleBar/MoraleFillBackground/MoraleFillTemplate

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
var _cached_morale_attack: int = 0
var _cached_morale_defense: int = 0
var _cached_morale_level: int = 0
var _cached_required_total: int = 0
var _morale_blocks: Array[Panel] = []
var _initialized: bool = false

const COLOR_HP_CURRENT: Color = Color(0.99, 0.1, 0.0, 0.7)
const COLOR_HP_LOST: Color = Color(0.5, 0.5, 0.5, 0.7)
const COLOR_MP_CURRENT: Color = Color(0, 1.0, 1.0, 0.7)
const COLOR_MP_LOST: Color = Color(0.2, 0.2, 0.2, 0.7)
const HP_BLINK_DURATION: float = 0.2
const MP_BLINK_DURATION: float = 0.2
const HP_BLOCK_SCALE: float = 0.8
const MP_DOTS_PER_UNIT: int = 4
const MP_DOT_FADE_OUT_DURATION: float = 0.2
const HEAL_FLASH_DURATION: float = 0.3

const UPGRADE_REQUIREMENTS: Array[int] = [7, 12, 15, 18]
const COLOR_MORALE_ATTACK: Color = Color(0.8, 0.2, 0.8, 0.8)
const COLOR_MORALE_DEFENSE: Color = Color(0.2, 0.4, 0.8, 0.8)
const COLOR_MORALE_FULL: Color = Color(0.7, 0.3, 1.0, 0.85)
const MORALE_BLOCK_SCALE: float = 0.8
const MORALE_BLINK_DURATION: float = 0.15

func _ready() -> void:
	request_area(RenderArea.DefaultArea.PLAYERS)
	hp_fill_template.visible = false
	if mp_unit_template:
		mp_unit_template.visible = false
	if morale_fill_template:
		morale_fill_template.visible = false

func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	if not (target_area is RenderAreaPlayers):
		return
	if mode == Mode.AUTO:
		target_area.local_player_received.connect(_on_local_player_received)
		if target_area.local_player:
			_on_local_player_received(target_area.local_player)

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
	var new_hp_max: int = player_data.modified_HP_max
	var new_hp_cur: int = player_data.HP
	var new_mp_max: int = player_data.modified_MP_max
	var new_mp_cur: int = player_data.MP
	var new_ap: int = player_data.AP
	var new_init_ap: int = player_data.modified_init_AP
	if not _initialized:
		_initialized = true
		_cached_hp_max = new_hp_max
		_cached_hp_current = new_hp_cur
		_cached_mp_max = new_mp_max
		_cached_mp_current = new_mp_cur
		_cached_ap_current = new_ap
		_cached_modified_init_ap = new_init_ap
		_apply_hp_animation(0, 0, new_hp_max, new_hp_cur)
		_update_hp_label(new_hp_cur, new_hp_max)
		_apply_mp_animation(0, 0, new_mp_max, new_mp_cur)
		_update_mp_label(max(0, new_mp_cur), max(0, new_mp_max))
		_update_ap_display(new_ap, new_init_ap)
		# 战意首次初始化（无动画）
		_cached_morale_level = player_data.morale_level
		_cached_morale_attack = player_data.morale_attack
		_cached_morale_defense = player_data.morale_defense
		var new_required: int = _get_morale_required(player_data.morale_level)
		_cached_required_total = new_required
		_update_morale_level(player_data.morale_level)
		_update_morale_value_text(player_data.morale_attack, player_data.morale_defense, new_required)
		_adjust_morale_bar_capacity(new_required)
		_fill_morale_blocks(player_data.morale_attack, player_data.morale_defense, new_required)
		return
	var hp_damage: int = old_hp - new_hp_cur
	var mp_damage: int = old_mp - new_mp_cur
	if new_hp_max != old_hp_max or new_hp_cur != old_hp:
		_apply_hp_animation(old_hp_max, old_hp, new_hp_max, new_hp_cur)
		_update_hp_label(new_hp_cur, new_hp_max)
		_cached_hp_max = new_hp_max
		_cached_hp_current = new_hp_cur
	if new_mp_max != old_mp_max or new_mp_cur != old_mp:
		_apply_mp_animation(old_mp_max, old_mp, new_mp_max, new_mp_cur)
		_update_mp_label(max(0, new_mp_cur), max(0, new_mp_max))
		_cached_mp_max = new_mp_max
		_cached_mp_current = new_mp_cur
	if new_ap != old_ap or new_init_ap != old_init_ap:
		_cached_ap_current = new_ap
		_cached_modified_init_ap = new_init_ap
		_update_ap_display(new_ap, new_init_ap)
	if hp_damage != 0 or mp_damage != 0:
		_trigger_damage_event(hp_damage, mp_damage)
	# 战意增量更新（带动画）
	var old_level: int = _cached_morale_level
	var old_attack: int = _cached_morale_attack
	var old_defense: int = _cached_morale_defense
	var old_required: int = _cached_required_total
	var new_level: int = player_data.morale_level
	var new_attack: int = player_data.morale_attack
	var new_defense: int = player_data.morale_defense
	var new_required: int = _get_morale_required(new_level)
	var level_changed: bool = old_level != new_level
	var value_changed: bool = old_attack != new_attack or old_defense != new_defense or old_required != new_required
	if level_changed:
		_cached_morale_level = new_level
		_update_morale_level(new_level)
	if value_changed:
		_cached_morale_attack = new_attack
		_cached_morale_defense = new_defense
		_cached_required_total = new_required
		_apply_morale_animation(old_attack, old_defense, old_required, new_attack, new_defense, new_required)
		_update_morale_value_text(new_attack, new_defense, new_required)

func _clear_display() -> void:
	_update_hp_label(0, 0)
	_update_mp_label(0, 0)
	for block in _hp_blocks:
		block.queue_free()
	_hp_blocks.clear()
	for unit in _mp_units:
		unit.queue_free()
	_mp_units.clear()
	_initialized = false
	_update_morale_level(0)
	_update_morale_value_text(0, 0, UPGRADE_REQUIREMENTS[0])
	_clear_morale_blocks()

# ==================== 战意更新方法（无文本动画） ====================
func _update_morale_level(new_level: int) -> void:
	morale_level_label.text = "Lv.%d" % new_level

func _update_morale_value_text(attack: int, defense: int, required: int) -> void:
	var total: int = attack + defense
	var text: String = "[color=#CC33CC]%d[/color]+[color=#3366CC]%d[/color]=[color=#AA66FF]%d[/color]/[color=#AA66FF]%d[/color]" % [attack, defense, total, required]
	morale_value_label.text = text
	morale_value_label.bbcode_enabled = true

func _get_morale_required(level: int) -> int:
	if level < UPGRADE_REQUIREMENTS.size():
		return UPGRADE_REQUIREMENTS[level]
	return 0

## 战意进度条动画（模仿 HP 条）
func _apply_morale_animation(old_attack: int, old_defense: int, old_required: int, new_attack: int, new_defense: int, new_required: int) -> void:
	# 先调整容量，新格子初始透明，移除多余格子
	_adjust_morale_bar_capacity(new_required)
	# 遍历当前所有格子，对颜色变化的格子播放闪烁
	for i in range(new_required):
		var block: Panel = _morale_blocks[i]
		var new_color: Color = _get_morale_block_color(i, new_attack, new_defense, new_required)
		var old_color: Color = Color.TRANSPARENT
		if i < old_required:
			old_color = _get_morale_block_color(i, old_attack, old_defense, old_required)
		if old_color != new_color:
			_start_morale_block_blink(block, old_color, new_color)

func _get_morale_block_color(index: int, attack: int, defense: int, required: int) -> Color:
	if required <= 0:
		return Color.TRANSPARENT
	var total := attack + defense
	if total >= required:
		var is_filled := index < attack or index >= required - defense
		return COLOR_MORALE_FULL if is_filled else Color.TRANSPARENT
	if index < attack:
		return COLOR_MORALE_ATTACK
	if index >= required - defense:
		return COLOR_MORALE_DEFENSE
	return Color.TRANSPARENT

## 战意格子闪烁
func _start_morale_block_blink(block: Panel, from_color: Color, to_color: Color) -> void:
	var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel") as StyleBoxFlat
	stylebox.bg_color = from_color
	UIAnimationUtils.blink_stylebox_bg_color(block, from_color, to_color, MORALE_BLINK_DURATION)

func _clear_morale_blocks() -> void:
	for block in _morale_blocks:
		block.queue_free()
	_morale_blocks.clear()

func _adjust_morale_bar_capacity(target_max: int) -> void:
	if target_max <= 0:
		_clear_morale_blocks()
		return
	if morale_fill_background.size.x <= 0:
		call_deferred(&"_adjust_morale_bar_capacity", target_max)
		return
	var current: int = _morale_blocks.size()
	if target_max > current:
		for i in range(current, target_max):
			var block: Panel = morale_fill_template.duplicate() as Panel
			block.visible = true
			var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
			block.add_theme_stylebox_override(&"panel", stylebox)
			morale_fill_background.add_child(block)
			_morale_blocks.append(block)
			stylebox.bg_color = Color.TRANSPARENT
		_relayout_morale_blocks()
	elif target_max < current:
		for i in range(target_max, current):
			var block: Panel = _morale_blocks.pop_back()
			block.queue_free()
		_relayout_morale_blocks()

func _relayout_morale_blocks() -> void:
	if _cached_required_total <= 0:
		return
	var block_width: float = morale_fill_background.size.x / _cached_required_total
	for i in range(_morale_blocks.size()):
		var block: Panel = _morale_blocks[i]
		block.size = Vector2(block_width * MORALE_BLOCK_SCALE, morale_fill_background.size.y * MORALE_BLOCK_SCALE)
		block.position = Vector2(i * block_width, 0)

func _fill_morale_blocks(attack: int, defense: int, required: int) -> void:
	if required <= 0:
		return
	for i in range(required):
		var block: Panel = _morale_blocks[i]
		var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel") as StyleBoxFlat
		stylebox.bg_color = _get_morale_block_color(i, attack, defense, required)

# ==================== HP 动画（已修复布局问题） ====================
func _apply_hp_animation(old_max: int, old_cur: int, new_max: int, new_cur: int) -> void:
	var clamped_new_cur: int = max(0, new_cur)
	var clamped_old_cur: int = max(0, old_cur)
	_adjust_hp_bar_capacity(new_max, clamped_new_cur)
	if new_max > old_max:
		for i in range(old_max, new_max):
			var block: Panel = _hp_blocks[i]
			var target: Color = COLOR_HP_CURRENT if i < clamped_new_cur else COLOR_HP_LOST
			var transparent: Color = Color(target.r, target.g, target.b, 0.0)
			_start_hp_block_blink(block, transparent, target)
		if old_cur != new_cur:
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
	else:
		if old_cur != new_cur:
			var start: int = max(0, min(clamped_old_cur, clamped_new_cur))
			var end: int = max(0, max(clamped_old_cur, clamped_new_cur) - 1)
			_animate_hp_range(start, end, new_cur < old_cur, new_max)

func _animate_hp_range(start: int, end: int, is_decrease: bool, limit: int) -> void:
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
		_relayout_hp_blocks(target_max)
	elif target_max < current:
		for i in range(target_max, current):
			var block: Panel = _hp_blocks.pop_back()
			block.queue_free()
		_relayout_hp_blocks(target_max)

func _relayout_hp_blocks(total_blocks: int) -> void:
	if total_blocks <= 0:
		return
	var block_width: float = hp_fill_background.size.x / total_blocks
	for i in range(_hp_blocks.size()):
		var block: Panel = _hp_blocks[i]
		block.size = Vector2(block_width * HP_BLOCK_SCALE, hp_fill_background.size.y * HP_BLOCK_SCALE)
		block.position = Vector2(i * block_width, 0)

func _start_hp_block_blink(block: Panel, from_color: Color, to_color: Color) -> void:
	var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel") as StyleBoxFlat
	stylebox.bg_color = from_color
	UIAnimationUtils.blink_stylebox_bg_color(block, from_color, to_color, HP_BLINK_DURATION)

func _start_hp_block_special_blink(block: Panel, target_color: Color) -> void:
	var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel") as StyleBoxFlat
	var start_color: Color = stylebox.bg_color
	var transparent: Color = Color(start_color.r, start_color.g, start_color.b, 0.0)
	var tween: Tween = create_tween()
	tween.tween_property(stylebox, ^"bg_color", transparent, HP_BLINK_DURATION)
	tween.tween_property(stylebox, ^"bg_color", target_color, HP_BLINK_DURATION)
	tween.tween_property(stylebox, ^"bg_color", transparent, HP_BLINK_DURATION)
	tween.tween_property(stylebox, ^"bg_color", target_color, HP_BLINK_DURATION)

# ==================== MP 动画 ====================
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
	var needed: int = ceili(float(target_max) / float(MP_DOTS_PER_UNIT))
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
	UIAnimationUtils.blink_color(dot, from_color, to_color, MP_BLINK_DURATION)

func _start_mp_dot_fade_out(dot: ColorRect, dot_index: int, new_max: int) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(dot, ^"color", Color.TRANSPARENT, MP_DOT_FADE_OUT_DURATION)
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

func _trigger_damage_event(hp_damage: int, mp_damage: int) -> void:
	if _cached_player_id == -1:
		return
	if not render_context:
		return
	var area: RenderArea = render_context.get_render_area(RenderArea.DefaultArea.PLAYERS)
	if area:
		var event: RenderEvent = RenderEvent.new().set_type(RenderEvent.DefaultType.DAMAGED)
		event.config[&"player_id"] = _cached_player_id
		event.config[&"hp_damage"] = hp_damage
		event.config[&"mp_damage"] = mp_damage
		area.tween_update(event)

func _update_hp_label(current: int, max_hp: int) -> void:
	hp_label.text = "%d / %d" % [current, max_hp]

func _update_mp_label(current: int, max_mp: int) -> void:
	mp_label.text = "%d / %d" % [current, max_mp]

func _update_ap_display(current: int, init_ap: int) -> void:
	ap_label.text = "%d / %d" % [current, init_ap]
