extends AreaFace

## 模式枚举：AUTO 自动跟随本地玩家，MANUAL 手动指定。
enum Mode { AUTO, MANUAL }
## 当前工作模式。
@export var mode: Mode = Mode.AUTO

## 预加载匿名组件类（相对于当前脚本的路径）。
const BlockIndicator = preload("block_indicator.gd")
const DotIndicator = preload("dot_indicator.gd")
const TextIconIndicator = preload("text_icon_indicator.gd")

## HP 指示器根节点。
@onready var hp_indicator: BlockIndicator = $HPBar
## MP 指示器根节点。
@onready var mp_indicator: DotIndicator = $MPContainer
## AP 指示器根节点。
@onready var ap_indicator: TextIconIndicator = $APContainer
## 战意指示器根节点。
@onready var morale_indicator: BlockIndicator = $MoraleBar
## 战意等级标签（由 AreaFace 直接管理）。
@onready var morale_level_label: Label = $MoraleBar/ValueLabel
## 战意攻防数值标签（富文本，由 AreaFace 直接管理）。
@onready var morale_value_label: RichTextLabel = $MoraleBar/MoraleValueLabel

## HP 最大值缓存。
var _cached_hp_max: int = 0
## HP 当前值缓存。
var _cached_hp_current: int = 0
## MP 最大值缓存。
var _cached_mp_max: int = 0
## MP 当前值缓存。
var _cached_mp_current: int = 0
## AP 当前值缓存。
var _cached_ap_current: int = 0
## 修正初始 AP 缓存。
var _cached_modified_init_ap: int = 0
## 战意攻击值缓存。
var _cached_morale_attack: int = 0
## 战意防御值缓存。
var _cached_morale_defense: int = 0
## 战意等级缓存。
var _cached_morale_level: int = 0
## 战意升级所需总值缓存。
var _cached_required_total: int = 0

var _current_player: RenderItem = null
var _cached_player_id: int = -1
var _initialized: bool = false

## HP 当前块颜色。
const COLOR_HP_CURRENT: Color = Color(0.99, 0.1, 0.0, 0.7)
## HP 损失块颜色。
const COLOR_HP_LOST: Color = Color(0.5, 0.5, 0.5, 0.7)
## MP 当前颜色。
const COLOR_MP_CURRENT: Color = Color(0, 1.0, 1.0, 0.7)
## MP 损失颜色。
const COLOR_MP_LOST: Color = Color(0.2, 0.2, 0.2, 0.7)
## 战意攻击颜色。
const COLOR_MORALE_ATTACK: Color = Color(0.8, 0.2, 0.8, 0.8)
## 战意防御颜色。
const COLOR_MORALE_DEFENSE: Color = Color(0.2, 0.4, 0.8, 0.8)
## 战意已满颜色。
const COLOR_MORALE_FULL: Color = Color(0.7, 0.3, 1.0, 0.85)

const HP_BLOCK_SCALE: float = 0.8
const HP_BLINK_DURATION: float = 0.2
const MP_DOTS_PER_UNIT: int = 4
const MP_BLINK_DURATION: float = 0.2
const MP_DOT_FADE_OUT_DURATION: float = 0.2
const MORALE_BLOCK_SCALE: float = 0.8
const MORALE_BLINK_DURATION: float = 0.15
const UPGRADE_REQUIREMENTS: Array[int] = [7, 12, 15, 18]

func _ready() -> void:
	request_area(RenderArea.DefaultArea.PLAYERS)

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
		hp_indicator.update_label_text(new_hp_cur, new_hp_max)
		_apply_mp_animation(0, 0, new_mp_max, new_mp_cur)
		mp_indicator.update_label_text(max(0, new_mp_cur), max(0, new_mp_max))
		ap_indicator.update_text(new_ap, new_init_ap)

		_cached_morale_level = player_data.morale_level
		_cached_morale_attack = player_data.morale_attack
		_cached_morale_defense = player_data.morale_defense
		var new_required: int = _get_morale_required(player_data.morale_level)
		_cached_required_total = new_required
		_update_morale_level(player_data.morale_level)
		_update_morale_value_text(player_data.morale_attack, player_data.morale_defense, new_required)
		_apply_morale_animation(0, 0, 0, player_data.morale_attack, player_data.morale_defense, new_required)
		return

	var hp_damage: int = old_hp - new_hp_cur
	var mp_damage: int = old_mp - new_mp_cur

	if new_hp_max != old_hp_max or new_hp_cur != old_hp:
		_apply_hp_animation(old_hp_max, old_hp, new_hp_max, new_hp_cur)
		hp_indicator.update_label_text(new_hp_cur, new_hp_max)
		_cached_hp_max = new_hp_max
		_cached_hp_current = new_hp_cur

	if new_mp_max != old_mp_max or new_mp_cur != old_mp:
		_apply_mp_animation(old_mp_max, old_mp, new_mp_max, new_mp_cur)
		mp_indicator.update_label_text(max(0, new_mp_cur), max(0, new_mp_max))
		_cached_mp_max = new_mp_max
		_cached_mp_current = new_mp_cur

	if new_ap != old_ap or new_init_ap != old_init_ap:
		_cached_ap_current = new_ap
		_cached_modified_init_ap = new_init_ap
		ap_indicator.update_text(new_ap, new_init_ap)

	if hp_damage != 0 or mp_damage != 0:
		_trigger_damage_event(hp_damage, mp_damage)

	var old_level: int = _cached_morale_level
	var old_attack: int = _cached_morale_attack
	var old_defense: int = _cached_morale_defense
	var old_required: int = _cached_required_total
	var new_level: int = player_data.morale_level
	var new_attack: int = player_data.morale_attack
	var new_defense: int = player_data.morale_defense
	var new_required: int = _get_morale_required(new_level)

	if old_level != new_level:
		_cached_morale_level = new_level
		_update_morale_level(new_level)

	if old_attack != new_attack or old_defense != new_defense or old_required != new_required:
		_cached_morale_attack = new_attack
		_cached_morale_defense = new_defense
		_cached_required_total = new_required
		_apply_morale_animation(old_attack, old_defense, old_required, new_attack, new_defense, new_required)
		_update_morale_value_text(new_attack, new_defense, new_required)

func _clear_display() -> void:
	hp_indicator.update_label_text(0, 0)
	mp_indicator.update_label_text(0, 0)
	ap_indicator.update_text(0, 0)
	hp_indicator.clear_blocks()
	mp_indicator.clear_dots()
	morale_indicator.clear_blocks()
	_initialized = false
	_update_morale_level(0)
	_update_morale_value_text(0, 0, UPGRADE_REQUIREMENTS[0])

# -------------------- HP 动画 --------------------
func _apply_hp_animation(old_max: int, old_cur: int, new_max: int, new_cur: int) -> void:
	var clamped_new_cur: int = max(0, new_cur)
	var clamped_old_cur: int = max(0, old_cur)
	hp_indicator.set_capacity(new_max)

	if new_max > old_max:
		for i in range(old_max, new_max):
			var target: Color = COLOR_HP_CURRENT if i < clamped_new_cur else COLOR_HP_LOST
			hp_indicator.blink_block(i, Color.TRANSPARENT, target, HP_BLINK_DURATION)

	if new_max < old_max:
		for i in range(new_max):
			var target: Color = COLOR_HP_CURRENT if i < clamped_new_cur else COLOR_HP_LOST
			hp_indicator.set_block_color(i, target, false)

	if old_cur != new_cur:
		var start: int = max(0, min(clamped_old_cur, clamped_new_cur))
		var end: int = max(0, max(clamped_old_cur, clamped_new_cur) - 1)
		var is_decrease: bool = new_cur < old_cur
		_animate_hp_range(start, end, is_decrease, new_max)

func _animate_hp_range(start: int, end: int, is_decrease: bool, limit: int) -> void:
	if start > end:
		return
	for i in range(start, end + 1):
		if i >= limit:
			continue
		var from_color: Color = COLOR_HP_CURRENT if is_decrease else COLOR_HP_LOST
		var to_color: Color = COLOR_HP_LOST if is_decrease else COLOR_HP_CURRENT
		hp_indicator.blink_block(i, from_color, to_color, HP_BLINK_DURATION)

# -------------------- MP 动画 --------------------
func _apply_mp_animation(old_max: int, old_cur: int, new_max: int, new_cur: int) -> void:
	var clamped_new_cur: int = max(0, new_cur)
	var clamped_old_cur: int = max(0, old_cur)
	mp_indicator.set_capacity(new_max)

	if new_max > old_max:
		for i in range(old_max, new_max):
			var target: Color = COLOR_MP_CURRENT if i < clamped_new_cur else COLOR_MP_LOST
			mp_indicator.blink_dot(i, Color.TRANSPARENT, target, MP_BLINK_DURATION)

	if new_max < old_max:
		for i in range(new_max, old_max):
			mp_indicator.fade_out_dot(i, MP_DOT_FADE_OUT_DURATION)

	if old_cur != new_cur:
		var start: int = max(0, min(clamped_old_cur, clamped_new_cur))
		var end: int = max(0, max(clamped_old_cur, clamped_new_cur) - 1)
		var is_decrease: bool = new_cur < old_cur
		_animate_mp_range(start, end, is_decrease, new_max)

func _animate_mp_range(start: int, end: int, is_decrease: bool, limit: int) -> void:
	if start > end:
		return
	for i in range(start, end + 1):
		if i >= limit:
			continue
		var from_color: Color = COLOR_MP_CURRENT if is_decrease else COLOR_MP_LOST
		var to_color: Color = COLOR_MP_LOST if is_decrease else COLOR_MP_CURRENT
		mp_indicator.blink_dot(i, from_color, to_color, MP_BLINK_DURATION)

# -------------------- 战意动画 --------------------
func _apply_morale_animation(old_attack: int, old_defense: int, old_required: int, new_attack: int, new_defense: int, new_required: int) -> void:
	morale_indicator.set_capacity(new_required)

	if new_required > old_required:
		for i in range(old_required, new_required):
			var color: Color = _get_morale_block_color(i, new_attack, new_defense, new_required)
			morale_indicator.blink_block(i, Color.TRANSPARENT, color, MORALE_BLINK_DURATION)

	var min_len: int = min(old_required, new_required)
	for i in range(min_len):
		var old_color: Color = _get_morale_block_color(i, old_attack, old_defense, old_required)
		var new_color: Color = _get_morale_block_color(i, new_attack, new_defense, new_required)
		if old_color != new_color:
			morale_indicator.blink_block(i, old_color, new_color, MORALE_BLINK_DURATION)

func _get_morale_block_color(index: int, attack: int, defense: int, required: int) -> Color:
	if required <= 0:
		return Color.TRANSPARENT
	var total: int = attack + defense
	if total >= required:
		var is_filled: bool = index < attack or index >= required - defense
		return COLOR_MORALE_FULL if is_filled else Color.TRANSPARENT
	if index < attack:
		return COLOR_MORALE_ATTACK
	if index >= required - defense:
		return COLOR_MORALE_DEFENSE
	return Color.TRANSPARENT

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

# -------------------- 伤害事件 --------------------
func _trigger_damage_event(hp_damage: int, mp_damage: int) -> void:
	if _cached_player_id == -1 or not render_context:
		return
	var _area: RenderArea = render_context.get_render_area(RenderArea.DefaultArea.PLAYERS)
	if _area:
		var event: RenderEvent = RenderEvent.new().set_type(RenderEvent.DefaultType.DAMAGED)
		event.config[&"player_id"] = _cached_player_id
		event.config[&"hp_damage"] = hp_damage
		event.config[&"mp_damage"] = mp_damage
		area.tween_update(event)  # 保持原样
