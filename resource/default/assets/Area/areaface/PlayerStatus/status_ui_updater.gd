## UI更新器：负责将数据变化应用到具体的指示器节点，并管理动画控制器。
extends RefCounted

const BlockIndicator = preload("block_indicator.gd")
const DotIndicator = preload("dot_indicator.gd")
const TextIconIndicator = preload("text_icon_indicator.gd")
const BreathAnimation = preload("breath_animation.gd")
const TremorAnimation = preload("tremor_animation.gd")
const ParticleManager = preload("ParticleManager.gd")
const C = preload("status_constants.gd")

## 引用UI节点
var hp_indicator: BlockIndicator
var mp_indicator: DotIndicator
var ap_indicator: TextIconIndicator
var morale_indicator: BlockIndicator
var morale_level_label: Label
var morale_value_label: RichTextLabel
var particle_manager: ParticleManager

## 动画控制器（纯逻辑，信号连接在此处完成）
var _breath_anim: BreathAnimation
var _tremor_anim: TremorAnimation
var _morale_breath_anim: BreathAnimation

func _init(
	hp_bar: BlockIndicator,
	mp_dots: DotIndicator,
	ap_text: TextIconIndicator,
	morale_bar: BlockIndicator,
	morale_lv_label: Label,
	morale_val_label: RichTextLabel,
	particles: ParticleManager
) -> void:
	hp_indicator = hp_bar
	mp_indicator = mp_dots
	ap_indicator = ap_text
	morale_indicator = morale_bar
	morale_level_label = morale_lv_label
	morale_value_label = morale_val_label
	particle_manager = particles

	# 创建动画控制器并连接信号
	_breath_anim = BreathAnimation.new()
	_breath_anim.brightness_updated.connect(_on_hp_brightness_updated)
	_breath_anim.set_block_count(0)

	_tremor_anim = TremorAnimation.new()
	_tremor_anim.offset_updated.connect(_on_hp_offset_updated)
	_tremor_anim.set_block_count(0)

	_morale_breath_anim = BreathAnimation.new()
	_morale_breath_anim.brightness_updated.connect(_on_morale_brightness_updated)
	_morale_breath_anim.set_block_count(0)
	_morale_breath_anim.amplitude = 0.15
	_morale_breath_anim.frame_interval = 4
	_morale_breath_anim.phase_offset = 2

	# 初始化容量
	hp_indicator.set_capacity(0)
	mp_indicator.set_capacity(0)
	morale_indicator.set_capacity(0)

# ----- 响应数据信号 -----
func on_hp_changed(old_hp: int, new_hp: int, old_max: int, new_max: int) -> void:
	_apply_hp_animation(old_max, old_hp, new_max, new_hp)

func on_mp_changed(old_mp: int, new_mp: int, old_max: int, new_max: int) -> void:
	_apply_mp_animation(old_max, old_mp, new_max, new_mp)

func on_ap_changed(old_ap: int, new_ap: int, old_init: int, new_init: int) -> void:
	ap_indicator.update_text(new_ap, new_init)

func on_morale_changed(old_level: int, new_level: int, old_attack: int, new_attack: int, old_defense: int, new_defense: int, old_required: int, new_required: int) -> void:
	_update_morale_level(new_level)
	_update_morale_value_text(new_attack, new_defense, new_required)
	_apply_morale_animation(old_attack, old_defense, old_required, new_attack, new_defense, new_required)
	if new_level > old_level:
		_emit_level_up_effect()

func on_clear_display() -> void:
	hp_indicator.update_label_text(0, 0)
	mp_indicator.update_label_text(0, 0)
	ap_indicator.update_text(0, 0)
	hp_indicator.clear_blocks()
	mp_indicator.clear_dots()
	morale_indicator.clear_blocks()
	hp_indicator.set_background_ratio(1.0, false)
	_breath_anim.set_active(false)
	_breath_anim.set_block_count(0)
	_tremor_anim.set_active(false)
	_tremor_anim.set_block_count(0)
	_tremor_anim.update_amplitude_by_hp(0, 1)
	_morale_breath_anim.set_active(false)
	_morale_breath_anim.set_block_count(0)
	_update_morale_level(0)
	_update_morale_value_text(0, 0, C.UPGRADE_REQUIREMENTS[0])

# ----- 内部动画实现 -----
func _apply_hp_animation(old_max: int, old_cur: int, new_max: int, new_cur: int) -> void:
	var clamped_new_cur: int = max(0, new_cur)
	var clamped_old_cur: int = max(0, old_cur)
	hp_indicator.set_capacity(new_max)
	_breath_anim.set_block_count(new_max)
	_tremor_anim.set_block_count(new_max)

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
			var flash_color: Color = Color.WHITE if new_cur > old_cur else Color.BLACK
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

func _apply_morale_animation(old_attack: int, old_defense: int, old_required: int, new_attack: int, new_defense: int, new_required: int) -> void:
	morale_indicator.set_capacity(new_required)
	_morale_breath_anim.set_block_count(new_required)

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

func _emit_level_up_effect() -> void:
	var blocks: Array[Panel] = morale_indicator.blocks
	if not blocks.size() > 0:
		return
	var last_block: Panel = blocks[blocks.size() - 1]
	var pos: Vector2 = last_block.global_position + Vector2(last_block.size.x * 0.5, last_block.size.y * 0.5)
	particle_manager.emit_level_up(pos)

# ----- 信号连接：动画控制器的输出 -----
func _on_hp_brightness_updated(index: int, brightness: float) -> void:
	if index < 0 or index >= hp_indicator.blocks.size():
		return
	if hp_indicator.block_animating[index]:
		return
	var base_color: Color = hp_indicator.block_base_colors[index]
	var new_color: Color = Color(
		clamp(base_color.r * brightness, 0.0, 1.0),
		clamp(base_color.g * brightness, 0.0, 1.0),
		clamp(base_color.b * brightness, 0.0, 1.0),
		base_color.a
	)
	var block: Panel = hp_indicator.blocks[index]
	var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel") as StyleBoxFlat
	stylebox.bg_color = new_color

func _on_hp_offset_updated(index: int, offset: Vector2) -> void:
	if index < 0 or index >= hp_indicator.blocks.size():
		return
	if hp_indicator.block_animating[index]:
		return
	hp_indicator.blocks[index].position = hp_indicator.block_base_positions[index] + offset

func _on_morale_brightness_updated(index: int, brightness: float) -> void:
	if index < 0 or index >= morale_indicator.blocks.size():
		return
	if morale_indicator.block_animating[index]:
		return
	var base_color: Color = morale_indicator.block_base_colors[index]
	var new_color: Color = Color(
		clamp(base_color.r * brightness, 0.0, 1.0),
		clamp(base_color.g * brightness, 0.0, 1.0),
		clamp(base_color.b * brightness, 0.0, 1.0),
		base_color.a
	)
	var block: Panel = morale_indicator.blocks[index]
	var stylebox: StyleBoxFlat = block.get_theme_stylebox(&"panel") as StyleBoxFlat
	stylebox.bg_color = new_color

## 每帧更新（由外部调用，驱动动画控制器）
func process(delta: float) -> void:
	_breath_anim.update()
	_tremor_anim.update()
	_morale_breath_anim.update()
