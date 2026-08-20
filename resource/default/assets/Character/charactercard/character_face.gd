extends CharacterFace

## 角色Sprite节点（需手动设置或通过路径获取）
@onready var character: Sprite2D = $Character

## ==================== 受击动画参数 ====================
## 受击动画基准伤害（用于归一化因子）
const DAMAGE_REFERENCE: float = 20.0
## 受击最小/最大旋转弧度（绝对值）
const MIN_ANGLE: float = 0.0
const MAX_ANGLE: float = PI / 16
## 受击最小/最大后仰位移（像素，绝对值）
const MIN_BACK_DIST: float = 20.0
const MAX_BACK_DIST: float = 100.0
## 受击最小/最大下压位移（像素，绝对值）
const MIN_DOWN_DIST: float = 5.0
const MAX_DOWN_DIST: float = 25.0
## 倒地状态下强制旋转角度（弧度）
const DOWN_ANGLE: float = PI / 2
## 受击最小/最大动画时长（秒）—— 基础时长 T = MIN_DURATION + (MAX_DURATION - MIN_DURATION) * factor
const MIN_DURATION: float = 0.04
const MAX_DURATION: float = 0.2
## 受击后恢复阶段时长系数（相对于 T）
const RECOVER_X_FACTOR: float = 10.0   # 水平归位
const RECOVER_Y_FACTOR: float = 7.0    # 垂直归位
const RECOVER_ROT_FACTOR: float = 5.0  # 旋转归位
## 残血恢复惩罚最大倍率（剩余HP比例越低，恢复越慢，最大为此倍数）
const RECOVER_PENALTY_MAX_MULTIPLIER: float = 4.0
## 总闪红时长系数（包含恢复）
const TOTAL_TIME_FACTOR: float = 1.0 + RECOVER_X_FACTOR
## ==================== 倒地第二段（从受击状态到平躺）参数 ====================
## 第二段时长系数（相对于受击基础时长 T）—— 与受击伤害强度正相关
const DOWN_FALL_DUR_FACTOR: float = 1.5
## ==================== 治疗起身动画参数（独立于受击强度，仅与剩余生命比例相关） ====================
## 起身动画的基准时长（秒），与实际受击伤害无关，仅与剩余生命比例相关
const RISE_BASE_DURATION: float = 0.3
## 起身动画各阶段时长系数（全部相对于 RISE_BASE_DURATION，独立配置）
const RISE_SINK_DURATION_FACTOR: float = 2.0   # 下沉阶段（身体下沉）时长系数
const RISE_ROT_DURATION_FACTOR: float = 3.5    # 旋转回正阶段时长系数（独立，与下沉并行但时长可不同）
const RISE_UP_DURATION_FACTOR: float = 2.0    # 起身（从下沉最低点回到正常高度）时长系数 = RISE_SINK_DURATION_FACTOR * 0.8
const RISE_WALK_DURATION_FACTOR: float = 4.0   # 走回原位（水平归位）时长系数
## 起身时下沉的额外距离（像素），使角色先蹲下再站起
const RISE_SINK_DISTANCE: float = 30.0
## 起身速度与剩余生命比例的关系：因子 sink_factor = 1 / max(0.1, remaining_hp_ratio)，并钳位到 [1, RISE_SINK_MAX_FACTOR]
const RISE_SINK_MAX_FACTOR: float = 2.0

## ==================== 运行时变量 ====================
var _current_hp_damage: int = 0
var _current_tween: Tween = null
var _is_mirrored: bool = false
## 是否处于倒地硬直（包括二段倒下过程中及完全倒地后），期间免疫正伤害，但治疗可立即起身
var _is_down_stagger: bool = false

var _original_position: Vector2
var _original_rotation: float


func _ready() -> void:
	_original_position = position
	_original_rotation = rotation
## 播放受击动画（重写父类方法，增加剩余生命比例参数）
## @param hp_damage: 生命值变化（正伤害，负治疗）
## @param mp_damage: 精神值变化（仅用于闪蓝）
## @param remaining_hp_ratio: 剩余生命比例（当前生命/最大生命），默认为1
func play_damage_animation(hp_damage: int, mp_damage: int, remaining_hp_ratio: float = 1.0) -> void:
	if hp_damage < 0:
		_handle_heal(hp_damage, remaining_hp_ratio)
		return
	# 正伤害或零伤害
	if hp_damage == 0 and mp_damage <= 0:
		return
	# 计算通用参数
	var factor: float = clampf(hp_damage / DAMAGE_REFERENCE, 0.0, 1.0)
	var T: float = MIN_DURATION + (MAX_DURATION - MIN_DURATION) * factor
	var flash_duration: float = TOTAL_TIME_FACTOR * T
	var dir: float = -1.0 if _is_mirrored else 1.0
	# 物理伤害（HP）
	if hp_damage > 0 and remaining_hp_ratio < 1:
		_play_physical_hit_animation(hp_damage, factor, T, flash_duration, dir, remaining_hp_ratio)
		return
	# 魔法伤害（MP）
	if mp_damage > 0:
		_play_magic_hit_animation(mp_damage, flash_duration)

## 处理治疗：若硬直且剩余生命>0，则播放起身动画
func _handle_heal(hp_damage: int, remaining_hp_ratio: float) -> void:
	if _is_down_stagger and remaining_hp_ratio > 0.0:
		_play_recover_from_down_animation(remaining_hp_ratio)

## 播放物理受击动画（正常或倒地）
func _play_physical_hit_animation(hp_damage: int, factor: float, T: float, flash_duration: float, dir: float, remaining_hp_ratio: float) -> void:
	if remaining_hp_ratio <= 0.0:
		_play_down_animation(factor, T, dir)
		if character and character.material is ShaderMaterial:
			ShaderEffectsUtils.flash_color(character, Color.RED, flash_duration, 1.0)
		return
	# 非致死：原有优先级逻辑（高伤害覆盖低伤害）
	if _current_tween != null and hp_damage >= _current_hp_damage:
		_kill_current_animation_if_exists()
	if _current_tween != null:
		return
	_current_hp_damage = hp_damage
	_play_normal_hit_animation(factor, T, dir, remaining_hp_ratio)
	if character and character.material is ShaderMaterial:
		ShaderEffectsUtils.flash_color(character, Color.RED, flash_duration, 1.0)
## 播放普通受击动画（有恢复阶段）
func _play_normal_hit_animation(factor: float, T: float, dir: float, remaining_hp_ratio: float) -> void:
	var angle: float = (MIN_ANGLE + (MAX_ANGLE - MIN_ANGLE) * factor) * dir
	var back_dist: float = (MIN_BACK_DIST + (MAX_BACK_DIST - MIN_BACK_DIST) * factor) * dir
	var down_dist: float = MIN_DOWN_DIST + (MAX_DOWN_DIST - MIN_DOWN_DIST) * factor
	var target_x: float = _original_position.x + back_dist
	var target_y: float = _original_position.y + down_dist
	var target_rot: float = _original_rotation + angle
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	if character is Sprite2D:
		character.frame = 1
	_add_hit_phase(_current_tween, target_x, target_y, target_rot, T)
	# 恢复阶段
	var t: float = clampf(remaining_hp_ratio, 0.0, 1.0)
	var recover_multiplier: float = 1.0 + (RECOVER_PENALTY_MAX_MULTIPLIER - 1.0) * (1.0 - t)
	_current_tween.chain()
	_add_recover_phase(_current_tween, _original_position.x, _original_position.y, _original_rotation, RECOVER_X_FACTOR * T * recover_multiplier, RECOVER_Y_FACTOR * T * recover_multiplier, RECOVER_ROT_FACTOR * T * recover_multiplier)
	_current_tween.chain().tween_callback(_on_physical_anim_finished)
## 添加受击阶段（并行位移+旋转）
func _add_hit_phase(tween: Tween, target_x: float, target_y: float, target_rot: float, duration: float) -> void:
	if rotation <= target_rot == _is_mirrored :
		return
	tween.tween_property(self, ^"position:x", target_x, duration).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, ^"position:y", target_y, duration).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, ^"rotation", target_rot, duration).set_ease(Tween.EASE_OUT)
## 添加恢复阶段（并行归位，使用TRANS_BACK弹性）
func _add_recover_phase(tween: Tween, target_x: float, target_y: float, target_rot: float, dur_x: float, dur_y: float, dur_rot: float) -> void:
	tween.tween_property(self, ^"position:x", target_x, dur_x).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, ^"position:y", target_y, dur_y).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, ^"rotation", target_rot, dur_rot).set_ease(Tween.EASE_IN)
## 播放倒地动画（两阶段）
func _play_down_animation(factor: float, T: float, dir: float) -> void:
	var angle1: float = (MIN_ANGLE + (MAX_ANGLE - MIN_ANGLE) * factor) * dir
	var back_dist1: float = (MIN_BACK_DIST + (MAX_BACK_DIST - MIN_BACK_DIST) * factor) * dir
	var down_dist1: float = MIN_DOWN_DIST + (MAX_DOWN_DIST - MIN_DOWN_DIST) * factor
	var target_x1: float = _original_position.x + back_dist1
	var target_y1: float = _original_position.y + down_dist1
	var target_rot1: float = _original_rotation + angle1
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	if character is Sprite2D:
		character.frame = 1
	_add_hit_phase(_current_tween, target_x1, target_y1, target_rot1, T)
	# 第二阶段
	_current_tween.chain()
	var fall_duration: float = DOWN_FALL_DUR_FACTOR
	var target_x2: float = target_x1
	var target_y2: float = _original_position.y
	var target_rot2: float = _original_rotation + DOWN_ANGLE * dir
	_add_down_fall_phase(_current_tween, target_x2, target_y2, target_rot2, fall_duration)
	_is_down_stagger = true
	_current_tween.chain().tween_callback(_on_down_anim_finished)
## 添加倒地第二段（平躺，使用缓入）
func _add_down_fall_phase(tween: Tween, target_x: float, target_y: float, target_rot: float, duration: float) -> void:
	tween.tween_property(self, ^"position:x", target_x, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	tween.tween_property(self, ^"position:y", target_y, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	tween.tween_property(self, ^"rotation", target_rot, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
## 播放魔法受击动画（仅闪蓝，帧变化）
func _play_magic_hit_animation(mp_damage: int, flash_duration: float) -> void:
	if character and character.material is ShaderMaterial:
		ShaderEffectsUtils.flash_color(character, Color.BLUE, flash_duration, 1.0)
	if character is Sprite2D:
		character.frame = 1
	create_tween().tween_callback(func():
		if is_instance_valid(character) and character is Sprite2D:
			ShaderEffectsUtils.crossfade_sprite_frame(character, 0, 0.2)
	).set_delay(flash_duration)
## 从倒地状态恢复的动画（治疗触发），时长仅与剩余生命比例相关
## 各阶段时长全部相对于 RISE_BASE_DURATION，旋转回正时长独立配置，不与下沉阶段耦合
## @param remaining_hp_ratio: 当前剩余生命比例（>0）
func _play_recover_from_down_animation(remaining_hp_ratio: float) -> void:
	_is_down_stagger = false
	_kill_current_animation_if_exists()
	_current_tween = create_tween()
	var sink_factor: float = 1.0 / max(0.1, remaining_hp_ratio)
	sink_factor = clampf(sink_factor, 1.0, RISE_SINK_MAX_FACTOR)
	# 1. 下沉 + 旋转回正（同时进行）
	var sink_duration: float = RISE_BASE_DURATION * RISE_SINK_DURATION_FACTOR * sink_factor
	var rot_duration: float = RISE_BASE_DURATION * RISE_ROT_DURATION_FACTOR * sink_factor
	var target_y_down: float = _original_position.y + RISE_SINK_DISTANCE
	var target_rot_down: float = _original_rotation
	_current_tween.set_parallel(true)
	_add_rise_sink_phase(_current_tween, target_y_down, sink_duration)
	_add_rise_rot_phase(_current_tween, target_rot_down, rot_duration)
	# 2. 起身（垂直归位）
	var up_duration: float = RISE_BASE_DURATION * RISE_UP_DURATION_FACTOR * sink_factor
	_current_tween.chain()
	_add_rise_up_phase(_current_tween, _original_position.y, up_duration)
	# 3. 走回原位（水平归位）
	var walk_duration: float = RISE_BASE_DURATION * RISE_WALK_DURATION_FACTOR * sink_factor
	_add_rise_walk_phase(_current_tween, _original_position.x, walk_duration)
	_current_tween.chain().tween_callback(_on_recover_from_down_finished)
	if character is Sprite2D:
		character.frame = 0
## 添加起身下沉阶段（垂直下压）
func _add_rise_sink_phase(tween: Tween, target_y: float, duration: float) -> void:
	tween.tween_property(self, ^"position:y", target_y, duration).set_ease(Tween.EASE_IN)
## 添加起身旋转回正阶段（使用TRANS_BACK弹性）
func _add_rise_rot_phase(tween: Tween, target_rot: float, duration: float) -> void:
	tween.tween_property(self, ^"rotation", target_rot, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
## 添加起身上升阶段（垂直归位）
func _add_rise_up_phase(tween: Tween, target_y: float, duration: float) -> void:
	tween.tween_property(self, ^"position:y", target_y, duration).set_ease(Tween.EASE_OUT)
## 添加起身走回阶段（水平归位，使用TRANS_BACK弹性）
func _add_rise_walk_phase(tween: Tween, target_x: float, duration: float) -> void:
	tween.tween_property(self, ^"position:x", target_x, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
## 倒地动画结束回调（保持硬直状态）
func _on_down_anim_finished() -> void:
	_current_hp_damage = 0
	_current_tween = null
	if character is Sprite2D:
		character.frame = 1
## 从倒地恢复完成回调（清除硬直状态）
func _on_recover_from_down_finished() -> void:
	_is_down_stagger = false
	_current_tween = null
	if character is Sprite2D:
		character.frame = 0
## 停止当前受击动画（重写父类方法）
func stop_damage_animation() -> void:
	_kill_current_animation_if_exists()
	position = _original_position
	rotation = _original_rotation
	if character and character is Sprite2D:
		character.frame = 0
## 强制杀死当前动画（如果有），重置相关状态
func _kill_current_animation_if_exists() -> void:
	if _current_tween != null and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null
		_current_hp_damage = 0
## 设置水平镜像（重写父类方法）
func set_mirrored(flip_h: bool) -> void:
	_is_mirrored = flip_h
	if character:
		character.flip_h = flip_h
## 物理受击动画结束回调（交叉渐变切回正常帧）
func _on_physical_anim_finished() -> void:
	ShaderEffectsUtils.crossfade_sprite_frame(character, 0, 0.2)
	_current_hp_damage = 0
	_current_tween = null
