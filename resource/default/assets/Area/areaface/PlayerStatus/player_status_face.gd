extends AreaFace

## 模式枚举：AUTO 自动跟随本地玩家，MANUAL 手动指定。
enum Mode { AUTO, MANUAL }
@export var mode: Mode = Mode.AUTO
## 预加载组件类
const BlockIndicator = preload("block_indicator.gd")
const DotIndicator = preload("dot_indicator.gd")
const TextIconIndicator = preload("text_icon_indicator.gd")
const BreathAnimation = preload("breath_animation.gd")
const TremorAnimation = preload("tremor_animation.gd")
const ParticleManager = preload("ParticleManager.gd")
const C = preload("status_constants.gd")
## 节点引用
@onready var hp_indicator: BlockIndicator = $HPBar
@onready var mp_indicator: DotIndicator = $MPContainer
@onready var ap_indicator: TextIconIndicator = $APContainer
@onready var morale_indicator: BlockIndicator = $MoraleBar
@onready var morale_level_label: Label = $MoraleBar/ValueLabel
@onready var morale_value_label: RichTextLabel = $MoraleBar/MoraleValueLabel
@onready var particle_manager: ParticleManager = $ParticleManager
## 缓存变量
var _cached_hp_max: int = 0
var _cached_hp_current: int = 0
var _cached_mp_max: int = 0
var _cached_mp_current: int = 0
var _cached_ap_current: int = 0
var _cached_modified_init_ap: int = 0
var _cached_morale_attack: int = 0
var _cached_morale_defense: int = 0
var _cached_morale_level: int = 0
var _cached_required_total: int = 0

var _current_player: RenderItem = null
var _cached_player_id: int = -1
var _initialized: bool = false
## 动画控制器
var _breath_anim: BreathAnimation = null
var _tremor_anim: TremorAnimation = null
var _morale_breath_anim: BreathAnimation = null
## 流血相关
var _bleed_frame_counter: int = 0
var _bleed_interval: int = 0
var _bleed_active: bool = false

func _ready() -> void:
	request_area(RenderArea.DefaultArea.PLAYERS)
	_breath_anim = BreathAnimation.new()
	_breath_anim.bind_indicator(hp_indicator)
	_tremor_anim = TremorAnimation.new()
	_tremor_anim.bind_indicator(hp_indicator)
	_morale_breath_anim = BreathAnimation.new()
	_morale_breath_anim.bind_indicator(morale_indicator)
	_morale_breath_anim.amplitude = 0.15
	_morale_breath_anim.frame_interval = 4
	_morale_breath_anim.phase_offset = 2

func _process(_delta: float) -> void:
	# 不可见时跳过所有帧更新，避免无效计算
	if not visible:
		return
	if _breath_anim:
		_breath_anim.update()
	if _tremor_anim:
		_tremor_anim.update()
	if _morale_breath_anim:
		_morale_breath_anim.update()
	if not _bleed_active or _cached_hp_current <= 0:
		_bleed_frame_counter = 0
		return
	_bleed_frame_counter += 1
	if _bleed_frame_counter % _bleed_interval != 0:
		return
	var available: int = _cached_hp_current
	var idx: int = randi_range(0, available - 1)
	var block: Panel = hp_indicator.blocks[idx]
	var dir: int = 1 if randf() > 0.5 else -1
	var pos_x: float = block.global_position.x + (block.size.x if dir == 1 else 0.0)
	var pos: Vector2 = Vector2(pos_x, block.global_position.y + block.size.y * 0.5)
	var ratio: float = float(_cached_hp_current) / float(_cached_hp_max) if _cached_hp_max > 0 else 0.0
	particle_manager.emit_blood_bleed_single(pos, dir, ratio)

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
		_update_bleed_state()
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
		if _initialized:
			_emit_level_up_effect()

	if old_attack != new_attack or old_defense != new_defense or old_required != new_required:
		_cached_morale_attack = new_attack
		_cached_morale_defense = new_defense
		_cached_required_total = new_required
		_apply_morale_animation(old_attack, old_defense, old_required, new_attack, new_defense, new_required)
		_update_morale_value_text(new_attack, new_defense, new_required)

	_update_bleed_state()

func _clear_display() -> void:
	hp_indicator.update_label_text(0, 0)
	mp_indicator.update_label_text(0, 0)
	ap_indicator.update_text(0, 0)
	hp_indicator.clear_blocks()
	mp_indicator.clear_dots()
	morale_indicator.clear_blocks()
	hp_indicator.set_background_ratio(1.0, false)
	_breath_anim.set_active(false)
	_tremor_anim.set_active(false)
	_tremor_anim.update_amplitude_by_hp(0, 1)
	_morale_breath_anim.set_active(false)
	_initialized = false
	_update_morale_level(0)
	_update_morale_value_text(0, 0, C.UPGRADE_REQUIREMENTS[0])
	_bleed_active = false

## ---- HP 动画 ----
func _apply_hp_animation(old_max: int, old_cur: int, new_max: int, new_cur: int) -> void:
	var clamped_new_cur: int = max(0, new_cur)
	var clamped_old_cur: int = max(0, old_cur)
	hp_indicator.set_capacity(new_max)
	var ratio: float = 1.0 if new_max == 0 else clamp(float(clamped_new_cur) / float(new_max), 0.0, 1.0)
	var use_gradient: bool = ratio > 0.5
	var blink_duration: float = C.HP_BLINK_DURATION
	if not use_gradient:
		var t: float = (0.5 - ratio) / 0.5
		blink_duration = lerp(C.MIN_BLINK_DURATION, C.HP_BLINK_DURATION, t)
	if new_max > old_max:
		for i in range(old_max, new_max):
			hp_indicator.set_block_color(i, C.COLOR_HP_LOST)
	var start: int = min(clamped_old_cur, clamped_new_cur)
	var end: int = max(clamped_old_cur, clamped_new_cur) - 1
	for i in range(start, end + 1):
		if i >= new_max:
			break
		var old_color: Color = C.COLOR_HP_CURRENT if i < clamped_old_cur else C.COLOR_HP_LOST
		var new_color: Color = C.COLOR_HP_CURRENT if i < clamped_new_cur else C.COLOR_HP_LOST
		if old_color == new_color:
			continue
		if use_gradient:
			var flash_color: Color
			if new_cur > old_cur:
				flash_color = Color.WHITE
			else:
				flash_color = Color.BLACK
			hp_indicator.set_block_color_two_step(i, flash_color, new_color, C.HP_TWO_STEP_FLASH_DURATION, C.HP_TWO_STEP_GRADIENT_DURATION)
		else:
			hp_indicator.blink_block(i, old_color, new_color, blink_duration)
	hp_indicator.set_background_ratio(ratio, true)
	if ratio > 0.5:
		_breath_anim.set_active(true)
		_tremor_anim.set_active(false)
	else:
		_breath_anim.set_active(false)
		_tremor_anim.set_active(clamped_new_cur > 0)
		_tremor_anim.update_amplitude_by_hp(clamped_new_cur, new_max)
	var hp_loss: int = clamped_old_cur - clamped_new_cur
	if hp_loss > 0:
		if clamped_new_cur == 0:
			var first_block: Panel = hp_indicator.blocks[0]
			var pos: Vector2 = first_block.global_position + Vector2(first_block.size.x * 0.5, first_block.size.y)
			particle_manager.emit_blood_gush(pos)
		else:
			var idx: int = clamped_new_cur
			if idx >= 0 and idx < hp_indicator.blocks.size():
				var block: Panel = hp_indicator.blocks[idx]
				var pos: Vector2 = block.global_position + Vector2(block.size.x, block.size.y * 0.5)
				particle_manager.emit_blood_hit(pos, hp_loss, ratio)

## ---- MP 动画 ----
func _apply_mp_animation(old_max: int, old_cur: int, new_max: int, new_cur: int) -> void:
	var clamped_new_cur: int = max(0, new_cur)
	var clamped_old_cur: int = max(0, old_cur)
	mp_indicator.set_capacity(new_max)

	if new_max > old_max:
		for i in range(old_max, new_max):
			var target: Color = C.COLOR_MP_CURRENT if i < clamped_new_cur else C.COLOR_MP_LOST
			mp_indicator.blink_dot(i, Color.TRANSPARENT, target, C.MP_BLINK_DURATION)

	if new_max < old_max:
		for i in range(new_max, old_max):
			mp_indicator.fade_out_dot(i, C.MP_DOT_FADE_OUT_DURATION)

	if old_cur != new_cur:
		var start: int = max(0, min(clamped_old_cur, clamped_new_cur))
		var end: int = max(0, max(clamped_old_cur, clamped_new_cur) - 1)
		var is_decrease: bool = new_cur < old_cur
		for i in range(start, end + 1):
			if i >= new_max:
				continue
			var from_color: Color = C.COLOR_MP_CURRENT if is_decrease else C.COLOR_MP_LOST
			var to_color: Color = C.COLOR_MP_LOST if is_decrease else C.COLOR_MP_CURRENT
			mp_indicator.blink_dot(i, from_color, to_color, C.MP_BLINK_DURATION)

## ---- 战意动画 ----
func _apply_morale_animation(old_attack: int, old_defense: int, old_required: int, new_attack: int, new_defense: int, new_required: int) -> void:
	morale_indicator.set_capacity(new_required)

	if new_required > old_required:
		for i in range(old_required, new_required):
			morale_indicator.set_block_color(i, Color.WHITE)
			morale_indicator.set_block_color_gradient(i, Color.TRANSPARENT, C.MORALE_NEW_BLOCK_FADE_DURATION)
	var min_len: int = min(old_required, new_required)
	for i in range(min_len):
		var old_color: Color = _get_morale_block_color(i, old_attack, old_defense, old_required)
		var new_color: Color = _get_morale_block_color(i, new_attack, new_defense, new_required)
		if old_color == new_color:
			continue
		morale_indicator.blink_block(i, old_color, new_color, C.MORALE_BLINK_DURATION)

	var total: int = new_attack + new_defense
	if total >= new_required and new_required > 0:
		_morale_breath_anim.set_active(true)
	else:
		_morale_breath_anim.set_active(false)

func _get_morale_block_color(index: int, attack: int, defense: int, required: int) -> Color:
	if required <= 0:
		return Color.TRANSPARENT
	var total: int = attack + defense
	if total >= required:
		var is_filled: bool = index < attack or index >= required - defense
		return C.COLOR_MORALE_FULL if is_filled else Color.TRANSPARENT
	if index < attack:
		return C.COLOR_MORALE_ATTACK
	if index >= required - defense:
		return C.COLOR_MORALE_DEFENSE
	return Color.TRANSPARENT

func _update_morale_level(new_level: int) -> void:
	morale_level_label.text = "Lv.%d" % new_level

func _update_morale_value_text(attack: int, defense: int, required: int) -> void:
	var total: int = attack + defense
	var text: String = "[color=#CC33CC]%d[/color]+[color=#3366CC]%d[/color]=[color=#AA66FF]%d[/color]/[color=#AA66FF]%d[/color]" % [attack, defense, total, required]
	morale_value_label.text = text
	morale_value_label.bbcode_enabled = true

func _get_morale_required(level: int) -> int:
	if level < C.UPGRADE_REQUIREMENTS.size():
		return C.UPGRADE_REQUIREMENTS[level]
	return 0

## ---- 伤害事件 ----
func _trigger_damage_event(hp_damage: int, mp_damage: int) -> void:
	if _cached_player_id == -1 or not render_context:
		return
	var _area: RenderArea = render_context.get_render_area(RenderArea.DefaultArea.PLAYERS)
	if not _area:
		return
	var event: RenderEvent = RenderEvent.new().set_type(RenderEvent.DefaultType.DAMAGED)
	event.config[&"player_id"] = _cached_player_id
	event.config[&"hp_damage"] = hp_damage
	event.config[&"mp_damage"] = mp_damage
	area.tween_update(event)

## ---- 粒子特效辅助 ----
func _emit_level_up_effect() -> void:
	var blocks: Array[Panel] = morale_indicator.blocks
	var pos: Vector2
	if not blocks.size() > 0:
		return
	var last_block: Panel = blocks[blocks.size() - 1]
	pos = last_block.global_position + Vector2(last_block.size.x * 0.5, last_block.size.y * 0.5)
	particle_manager.emit_level_up(pos)

func _update_bleed_state() -> void:
	if _cached_hp_max <= 0:
		_bleed_active = false
		return
	var ratio: float = float(_cached_hp_current) / float(_cached_hp_max)
	if _cached_hp_current > 0 and ratio <= 0.5:
		_bleed_active = true
		var t: float = ratio * 2.0
		_bleed_interval = int(lerp(float(C.BLEED_INTERVAL_AT_0), float(C.BLEED_INTERVAL_AT_50), t))
	else:
		_bleed_active = false
