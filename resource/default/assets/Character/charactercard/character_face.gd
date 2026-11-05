## 角色形象：把受击/治疗归约为位移-旋转-帧切换的补间编排，并维护倒地硬直状态。
extends CharacterFace

#==vars==
## 角色Sprite节点
@onready var character: Sprite2D = $Character
## 角色配置文件（可在编辑器中指定测试资源）
@export var profile: CharacterProfile = null
## 受击动画补间槽位（同一时刻只保留一条）
var damage_tween: Tween = null
## 帧切换延迟补间槽位（同一时刻只保留一条）
var frame_tween: Tween = null
## 当前受击伤害值（用于防止动画叠加）
var _current_hp_damage: int = 0
## 是否水平镜像
var _is_mirrored: bool = false
## 是否处于倒地硬直状态
var _is_down_stagger: bool = false
## 原始位置（用于还原）
var _original_position: Vector2
## 原始旋转（用于还原）
var _original_rotation: float

#==consts==
## 受击动画基准伤害（用于归一化因子）
const DAMAGE_REFERENCE: float = 20.0
## 受击最小/最大旋转弧度（绝对值）
const MIN_ANGLE: float = 0.0
## 受击最大旋转弧度
const MAX_ANGLE: float = PI / 16
## 受击最小后仰位移（像素，绝对值）
const MIN_BACK_DIST: float = 20.0
## 受击最大后仰位移（像素）
const MAX_BACK_DIST: float = 100.0
## 受击最小下压位移（像素，绝对值）
const MIN_DOWN_DIST: float = 5.0
## 受击最大下压位移（像素）
const MAX_DOWN_DIST: float = 25.0
## 倒地状态下强制旋转角度（弧度）
const DOWN_ANGLE: float = PI / 2
## 受击最小动画时长（秒）—— 基础时长 T = MIN_DURATION + (MAX_DURATION - MIN_DURATION) * factor
const MIN_DURATION: float = 0.04
## 受击最大动画时长（秒）
const MAX_DURATION: float = 0.2
## 受击后恢复阶段时长系数（相对于 T）
const RECOVER_X_FACTOR: float = 10.0
## 恢复阶段竖直位移系数
const RECOVER_Y_FACTOR: float = 7.0
## 恢复阶段旋转系数
const RECOVER_ROT_FACTOR: float = 5.0
## 残血恢复惩罚最大倍率（剩余HP比例越低，恢复越慢，最大为此倍数）
const RECOVER_PENALTY_MAX_MULTIPLIER: float = 4.0
## 受击修正百分数的基准值（配置中的 100 与基准观感一致）
const PERCENT_BASE: int = 100
## 受击动画总时长上限（秒）；受击段与回位段各自不超过它的一半
const MAX_HIT_ANIMATION_DURATION: float = 20.0
## 单个受击分段的时长上限（秒）
const MAX_HIT_PHASE_DURATION: float = MAX_HIT_ANIMATION_DURATION / 2.0
## 回位速度的最小百分数（低于此值按此值计算）
const MIN_RECOVER_SPEED_PERCENT: int = 10
## 起身（垂直复位）时长占回位时长的基准比例
const RISE_NEUTRAL_RATIO: float = RECOVER_Y_FACTOR / RECOVER_X_FACTOR
## 回正（旋转复位）时长占回位时长的基准比例
const UPRIGHT_NEUTRAL_RATIO: float = RECOVER_ROT_FACTOR / RECOVER_X_FACTOR
## 总闪红时长系数（包含恢复）
const TOTAL_TIME_FACTOR: float = 1.0 + RECOVER_X_FACTOR
## 倒地第二段（从受击状态到平躺）时长（秒）；直接以秒计算，不随受击基础时长 T 缩放
const DOWN_FALL_DURATION: float = 1.5
## 起身动画的基准时长（秒），与实际受击伤害无关，仅与剩余生命比例相关
const RISE_BASE_DURATION: float = 0.3
## 起身动画各阶段时长系数（全部相对于 RISE_BASE_DURATION）
const RISE_SINK_DURATION_FACTOR: float = 2.0
## 起身旋转阶段时长系数
const RISE_ROT_DURATION_FACTOR: float = 3.5
## 起身站起阶段时长系数
const RISE_UP_DURATION_FACTOR: float = 2.0
## 起身走回阶段时长系数
const RISE_WALK_DURATION_FACTOR: float = 4.0
## 起身时下沉的额外距离（像素），使角色先蹲下再站起
const RISE_SINK_DISTANCE: float = 30.0
## 起身速度与剩余生命比例的关系因子，钳位到 [1, RISE_SINK_MAX_FACTOR]
const RISE_SINK_MAX_FACTOR: float = 2.0
## 切换回正常帧时的交叉渐变时长（秒）
const CROSSFADE_DURATION: float = 0.3
## 受击阶段水平位移缓动（接缝默认值）
const EASE_HIT_X: Tween.EaseType = Tween.EASE_OUT
## 受击阶段竖直位移缓动（接缝默认值）
const EASE_HIT_Y: Tween.EaseType = Tween.EASE_IN_OUT
## 受击阶段旋转缓动（接缝默认值）
const EASE_HIT_ROT: Tween.EaseType = Tween.EASE_OUT
## 恢复阶段位移缓动（接缝默认值）
const EASE_RECOVER: Tween.EaseType = Tween.EASE_IN_OUT
## 恢复阶段旋转缓动（接缝默认值）
const EASE_RECOVER_ROT: Tween.EaseType = Tween.EASE_IN
## 倒地平躺过渡（接缝默认值）
const TRANS_DOWN_FALL: Tween.TransitionType = Tween.TRANS_QUART
## 倒地平躺缓动（接缝默认值）
const EASE_DOWN_FALL: Tween.EaseType = Tween.EASE_IN
## 起身弹性过渡（接缝默认值）
const TRANS_RISE_BACK: Tween.TransitionType = Tween.TRANS_BACK
## 起身下沉缓动（接缝默认值）
const EASE_RISE_SINK: Tween.EaseType = Tween.EASE_IN
## 起身旋转缓动（接缝默认值）
const EASE_RISE_ROT: Tween.EaseType = Tween.EASE_OUT
## 起身上升缓动（接缝默认值）
const EASE_RISE_UP: Tween.EaseType = Tween.EASE_OUT
## 起身走回缓动（接缝默认值）
const EASE_RISE_WALK: Tween.EaseType = Tween.EASE_IN_OUT

#==lifecycle==
## 就绪：记录原始位姿并应用角色配置。
## @override
func _ready() -> void:
	_original_position = position
	_original_rotation = rotation
	if profile and profile.texture and character:
		character.texture = profile.texture
		character.hframes = profile.hframes
		character.vframes = profile.vframes
		character.frame = profile.idle_frame_normal

#==record==
## 受击首段目标位姿（三项总是成组使用）。
## @record
class HitGeometry:
	## 目标水平位置
	var target_x: float
	## 目标垂直位置
	var target_y: float
	## 目标旋转（弧度）
	var target_rot: float

	## 构造：记录首段落点
	func _init(p_target_x: float, p_target_y: float, p_target_rot: float) -> void:
		target_x = p_target_x
		target_y = p_target_y
		target_rot = p_target_rot

#==compute==
## 百分数转换为倍率，不做任何钳制。
## @pure
static func percent_to_scale(percent: int) -> float:
	return percent / float(PERCENT_BASE)
## 计算受击首段的平移与旋转落点：基准几何乘上修正百分数。
## 击退幅度在此钳制到 0（负值不改变击退方向）；屈膝与后倾允许负值，故不钳制。
## 受击修正包为空时按全 100 计算，即复现基准几何。
## @pure
static func compute_hit_geometry(original_position: Vector2, original_rotation: float, factor: float, dir: float, pack: CharacterHitPack = null) -> HitGeometry:
	var knockback_percent: int = pack.knockback_percent if pack else PERCENT_BASE
	var knee_bend_percent: int = pack.knee_bend_percent if pack else PERCENT_BASE
	var lean_back_percent: int = pack.lean_back_percent if pack else PERCENT_BASE
	var knockback_scale: float = maxf(percent_to_scale(knockback_percent), 0.0)
	var back_dist: float = (MIN_BACK_DIST + (MAX_BACK_DIST - MIN_BACK_DIST) * factor) * dir * knockback_scale
	var down_dist: float = (MIN_DOWN_DIST + (MAX_DOWN_DIST - MIN_DOWN_DIST) * factor) * percent_to_scale(knee_bend_percent)
	var angle: float = (MIN_ANGLE + (MAX_ANGLE - MIN_ANGLE) * factor) * dir * percent_to_scale(lean_back_percent)
	return HitGeometry.new(original_position.x + back_dist, original_position.y + down_dist, original_rotation + angle)
## 分量复位时长：基准分量时长乘以力度修正因子。
## 100 时修正因子恰为 1.0，基准分量时长逐位不变；0 时与回位同速。力度钳到 0，修正因子钳到 0。
## @pure
static func recover_duration(base_component_duration: float, neutral_ratio: float, percent: int) -> float:
	var force_scale: float = maxf(percent_to_scale(percent), 0.0)
	var correction: float = 1.0 + (1.0 / neutral_ratio - 1.0) * (1.0 - force_scale)
	return base_component_duration * maxf(correction, 0.0)
## 取当前角色的受击修正包；未配置时为 null，静态计算方法按全 100 处理。
## @nullable_pure
func get_hit_pack() -> CharacterHitPack:
	return profile.hit_pack if profile else null
## 回位段时长：基准时长乘以速度倍率（100 时为 1.0，低于最小百分数按最小百分数），再钳到分段上限；
## 速度非正时直接取分段上限。
## @pure
static func recover_total_duration(base_duration: float, percent: int) -> float:
	if percent <= 0:
		return MAX_HIT_PHASE_DURATION
	var speed_scale: float = float(PERCENT_BASE) / maxf(float(percent), float(MIN_RECOVER_SPEED_PERCENT))
	return minf(base_duration * speed_scale, MAX_HIT_PHASE_DURATION)

#==assembly==
## 受击阶段装配：并行位移与旋转。
## 受击演出由 [method play_damage_animation] 的互斥门拦截重复触发，故不做逐目标跳过。
## 条件参数为落点与时长，幅度参数（缓动）为接缝，不覆盖时同条件即对齐。
## @atomic @seam
static func do_hit_phase(
		tween: Tween,
		node: Control,
		target_x: float,
		target_y: float,
		target_rot: float,
		duration: float,
		ease_x_overriding: Tween.EaseType = EASE_HIT_X,
		ease_y_overriding: Tween.EaseType = EASE_HIT_Y,
		ease_rot_overriding: Tween.EaseType = EASE_HIT_ROT) -> void:
	tween.tween_property(node, ^"position:x", target_x, duration).set_ease(ease_x_overriding)
	tween.tween_property(node, ^"position:y", target_y, duration).set_ease(ease_y_overriding)
	tween.tween_property(node, ^"rotation", target_rot, duration).set_ease(ease_rot_overriding)
## 恢复阶段装配：并行归位，带弹性回拉。
## @atomic @seam
static func do_recover_phase(
		tween: Tween,
		node: Control,
		target_x: float,
		target_y: float,
		target_rot: float,
		dur_x: float,
		dur_y: float,
		dur_rot: float,
		ease_overriding: Tween.EaseType = EASE_RECOVER,
		trans_overriding: Tween.TransitionType = TRANS_RISE_BACK,
		ease_rot_overriding: Tween.EaseType = EASE_RECOVER_ROT) -> void:
	tween.tween_property(node, ^"position:x", target_x, dur_x).set_ease(ease_overriding).set_trans(trans_overriding)
	tween.tween_property(node, ^"position:y", target_y, dur_y).set_ease(ease_overriding).set_trans(trans_overriding)
	tween.tween_property(node, ^"rotation", target_rot, dur_rot).set_ease(ease_rot_overriding)
## 倒地第二段装配：平躺。
## @atomic @seam
static func do_down_fall_phase(
		tween: Tween,
		node: Control,
		target_x: float,
		target_y: float,
		target_rot: float,
		duration: float,
		ease_overriding: Tween.EaseType = EASE_DOWN_FALL,
		trans_overriding: Tween.TransitionType = TRANS_DOWN_FALL) -> void:
	tween.tween_property(node, ^"position:x", target_x, duration).set_ease(ease_overriding).set_trans(trans_overriding)
	tween.tween_property(node, ^"position:y", target_y, duration).set_ease(ease_overriding).set_trans(trans_overriding)
	tween.tween_property(node, ^"rotation", target_rot, duration).set_ease(ease_overriding).set_trans(trans_overriding)
## 起身下沉阶段装配：垂直下压。
## @atomic @seam
static func do_rise_sink_phase(tween: Tween, node: Control, target_y: float, duration: float, ease_overriding: Tween.EaseType = EASE_RISE_SINK) -> void:
	tween.tween_property(node, ^"position:y", target_y, duration).set_ease(ease_overriding)
## 起身旋转回正阶段装配。
## @atomic @seam
static func do_rise_rot_phase(
		tween: Tween,
		node: Control,
		target_rot: float,
		duration: float,
		ease_overriding: Tween.EaseType = EASE_RISE_ROT,
		trans_overriding: Tween.TransitionType = TRANS_RISE_BACK) -> void:
	tween.tween_property(node, ^"rotation", target_rot, duration).set_ease(ease_overriding).set_trans(trans_overriding)
## 起身上升阶段装配：垂直归位。
## @atomic @seam
static func do_rise_up_phase(tween: Tween, node: Control, target_y: float, duration: float, ease_overriding: Tween.EaseType = EASE_RISE_UP) -> void:
	tween.tween_property(node, ^"position:y", target_y, duration).set_ease(ease_overriding)
## 起身走回阶段装配：水平归位。
## @atomic @seam
static func do_rise_walk_phase(
		tween: Tween,
		node: Control,
		target_x: float,
		duration: float,
		ease_overriding: Tween.EaseType = EASE_RISE_WALK,
		trans_overriding: Tween.TransitionType = TRANS_RISE_BACK) -> void:
	tween.tween_property(node, ^"position:x", target_x, duration).set_ease(ease_overriding).set_trans(trans_overriding)

#==hooks==
## 播放受击动画（重写父类钩子）。
## @override
func play_damage_animation(hp_damage: int, mp_damage: int, remaining_hp_ratio: float = 1.0) -> void:
	if hp_damage < 0:
		_handle_heal(hp_damage, remaining_hp_ratio)
		return
	if hp_damage == 0 and mp_damage <= 0:
		return
	var factor: float = clampf(hp_damage / DAMAGE_REFERENCE, 0.0, 1.0)
	var T: float = MIN_DURATION + (MAX_DURATION - MIN_DURATION) * factor
	var flash_duration: float = TOTAL_TIME_FACTOR * T
	var dir: float = -1.0 if _is_mirrored else 1.0
	if hp_damage > 0 and remaining_hp_ratio < 1:
		_play_physical_hit_animation(hp_damage, factor, T, flash_duration, dir, remaining_hp_ratio)
		return
	if mp_damage > 0:
		_play_magic_hit_animation(mp_damage, flash_duration)
## 停止当前受击动画（重写父类钩子）：清槽位并瞬时归位。
## @override
func stop_damage_animation() -> void:
	_kill_current_animation_if_exists()
	frame_tween = UIAnimationUtils.clear_tween(frame_tween)
	position = _original_position
	rotation = _original_rotation
	_crossfade_to_normal()
## 设置水平镜像（重写父类钩子）。
## @override
func set_mirrored(flip_h: bool) -> void:
	_is_mirrored = flip_h
	if character:
		character.flip_h = flip_h

#==internal==
## 处理治疗：若硬直且剩余生命>0，则播放起身动画
## @internal
func _handle_heal(hp_damage: int, remaining_hp_ratio: float) -> void:
	if _is_down_stagger and remaining_hp_ratio > 0.0:
		_play_recover_from_down_animation(remaining_hp_ratio)
## 播放物理受击动画（正常或倒地）
## @internal
func _play_physical_hit_animation(hp_damage: int, factor: float, T: float, flash_duration: float, dir: float, remaining_hp_ratio: float) -> void:
	if remaining_hp_ratio <= 0.0:
		_play_down_animation(factor, T, dir)
		_flash_sprite(Color.RED, flash_duration)
		return
	if damage_tween != null and hp_damage >= _current_hp_damage:
		_kill_current_animation_if_exists()
	if damage_tween != null:
		return
	_current_hp_damage = hp_damage
	_play_normal_hit_animation(factor, T, dir, remaining_hp_ratio)
	_flash_sprite(Color.RED, flash_duration)
## 播放普通受击动画（有恢复阶段）
## @internal
func _play_normal_hit_animation(factor: float, T: float, dir: float, remaining_hp_ratio: float) -> void:
	var pack: CharacterHitPack = get_hit_pack()
	var geometry: HitGeometry = compute_hit_geometry(_original_position, _original_rotation, factor, dir, pack)
	var t: float = clampf(remaining_hp_ratio, 0.0, 1.0)
	var recover_multiplier: float = 1.0 + (RECOVER_PENALTY_MAX_MULTIPLIER - 1.0) * (1.0 - t)
	var hit_duration: float = minf(T, MAX_HIT_PHASE_DURATION)
	var recover_speed_percent: int = pack.recover_speed_percent if pack else PERCENT_BASE
	var recover_x_base: float = RECOVER_X_FACTOR * T * recover_multiplier
	var recover_x_duration: float = recover_total_duration(recover_x_base, recover_speed_percent)
	var speed_scale: float = recover_x_duration / recover_x_base
	var knee_force_percent: int = pack.knee_force_percent if pack else PERCENT_BASE
	var upright_force_percent: int = pack.upright_force_percent if pack else PERCENT_BASE
	var recover_y_duration: float = recover_duration(RECOVER_Y_FACTOR * T * recover_multiplier * speed_scale, RISE_NEUTRAL_RATIO, knee_force_percent)
	var recover_rot_duration: float = recover_duration(RECOVER_ROT_FACTOR * T * recover_multiplier * speed_scale, UPRIGHT_NEUTRAL_RATIO, upright_force_percent)
	damage_tween = create_tween()
	damage_tween.set_parallel(true)
	if character:
		character.frame = profile.hit_frame if profile else 1
	do_hit_phase(damage_tween, self, geometry.target_x, geometry.target_y, geometry.target_rot, hit_duration)
	damage_tween.chain()
	do_recover_phase(damage_tween, self, _original_position.x, _original_position.y, _original_rotation, recover_x_duration, recover_y_duration, recover_rot_duration)
	damage_tween.chain().tween_callback(_on_physical_anim_finished)
## 播放倒地动画（两阶段）
## @internal
func _play_down_animation(factor: float, T: float, dir: float) -> void:
	# 首段与普通受击共用同一几何计算，受击修正包在此同样生效
	var geometry: HitGeometry = compute_hit_geometry(_original_position, _original_rotation, factor, dir, get_hit_pack())
	var hit_duration: float = minf(T, MAX_HIT_PHASE_DURATION)
	damage_tween = create_tween()
	damage_tween.set_parallel(true)
	if character:
		character.frame = profile.hit_frame if profile else 1
	do_hit_phase(damage_tween, self, geometry.target_x, geometry.target_y, geometry.target_rot, hit_duration)
	damage_tween.chain()
	var fall_duration: float = DOWN_FALL_DURATION
	var target_x2: float = geometry.target_x
	var target_y2: float = _original_position.y
	var target_rot2: float = _original_rotation + DOWN_ANGLE * dir
	do_down_fall_phase(damage_tween, self, target_x2, target_y2, target_rot2, fall_duration)
	_is_down_stagger = true
	damage_tween.chain().tween_callback(_on_down_anim_finished)
## 播放魔法受击动画（仅闪蓝，帧变化）
## @internal
func _play_magic_hit_animation(mp_damage: int, flash_duration: float) -> void:
	_flash_sprite(Color.BLUE, flash_duration)
	if character:
		character.frame = profile.hit_frame if profile else 1
	var delayed: Tween = create_tween()
	delayed.tween_callback(_crossfade_to_normal).set_delay(flash_duration)
	frame_tween = UIAnimationUtils.replace_tween(frame_tween, delayed)
## 从倒地状态恢复的动画（治疗触发），时长仅与剩余生命比例相关
## @internal
func _play_recover_from_down_animation(remaining_hp_ratio: float) -> void:
	_is_down_stagger = false
	_kill_current_animation_if_exists()
	damage_tween = create_tween()
	var sink_factor: float = 1.0 / max(0.1, remaining_hp_ratio)
	sink_factor = clampf(sink_factor, 1.0, RISE_SINK_MAX_FACTOR)
	_crossfade_to_normal()
	var sink_duration: float = RISE_BASE_DURATION * RISE_SINK_DURATION_FACTOR * sink_factor
	var rot_duration: float = RISE_BASE_DURATION * RISE_ROT_DURATION_FACTOR * sink_factor
	var target_y_down: float = _original_position.y + RISE_SINK_DISTANCE
	var target_rot_down: float = _original_rotation
	damage_tween.set_parallel(true)
	do_rise_sink_phase(damage_tween, self, target_y_down, sink_duration)
	do_rise_rot_phase(damage_tween, self, target_rot_down, rot_duration)
	var up_duration: float = RISE_BASE_DURATION * RISE_UP_DURATION_FACTOR * sink_factor
	damage_tween.chain()
	do_rise_up_phase(damage_tween, self, _original_position.y, up_duration)
	var walk_duration: float = RISE_BASE_DURATION * RISE_WALK_DURATION_FACTOR * sink_factor
	do_rise_walk_phase(damage_tween, self, _original_position.x, walk_duration)
	damage_tween.chain().tween_callback(_on_recover_from_down_finished)
## 倒地动画结束回调（保持硬直状态）
## @internal
func _on_down_anim_finished() -> void:
	_current_hp_damage = 0
	damage_tween = null
	if character:
		character.frame = profile.hit_frame if profile else 1
## 从倒地恢复完成回调（清除硬直状态）
## @internal
func _on_recover_from_down_finished() -> void:
	_is_down_stagger = false
	damage_tween = null
## 物理受击动画结束回调（通过交叉渐变切回正常帧）
## @internal
func _on_physical_anim_finished() -> void:
	_current_hp_damage = 0
	damage_tween = null
	_crossfade_to_normal()
## 强制杀死当前动画（如果有），重置相关状态
## @internal
func _kill_current_animation_if_exists() -> void:
	damage_tween = UIAnimationUtils.clear_tween(damage_tween)
	_current_hp_damage = 0
## 内部闪烁辅助（独立封装）
## @internal
func _flash_sprite(color: Color, duration: float) -> void:
	if character and character.material is ShaderMaterial:
		ShaderEffectsUtils.flash_color(character, color, duration, 1.0)
## 使用交叉渐变将精灵帧切换为正常帧（frame=0）
## @internal
func _crossfade_to_normal() -> void:
	if not character:
		return
	var target_frame: int = profile.idle_frame_normal if profile else 0
	if character.frame == target_frame:
		return
	if character.material is ShaderMaterial:
		ShaderEffectsUtils.crossfade_sprite_frame(character, target_frame, CROSSFADE_DURATION)
		return
	character.frame = target_frame
