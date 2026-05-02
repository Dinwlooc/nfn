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
	# 硬直状态下，只允许治疗效果（hp_damage < 0）
	if _is_down_stagger and hp_damage >= 0:
		return
	# 治疗处理：若硬直且治疗，立即尝试恢复（会清除硬直）
	if hp_damage < 0:
		var new_ratio: float = remaining_hp_ratio
		if _is_down_stagger and new_ratio > 0.0:
			_play_recover_from_down_animation(remaining_hp_ratio)
		return
	# 正伤害处理
	if hp_damage == 0 and mp_damage <= 0:
		return
	# 计算动画参数
	var factor: float = clampf(hp_damage / DAMAGE_REFERENCE, 0.0, 1.0)
	var T: float = MIN_DURATION + (MAX_DURATION - MIN_DURATION) * factor
	var flash_duration: float = TOTAL_TIME_FACTOR * T
	# 物理受击（HP伤害）
	if hp_damage > 0 and remaining_hp_ratio < 1:
		# 若已有更严重的伤害正在播放，则跳过本次低优先级伤害
		if _current_tween != null and hp_damage >= _current_hp_damage:
			_current_tween.kill()
			_current_tween = null
			_current_hp_damage = 0
		if _current_tween == null:
			_current_hp_damage = hp_damage
			# 根据镜像决定方向（镜像时 X 位移和旋转取反）
			var dir: float = -1.0 if _is_mirrored else 1.0
			# 判断是否会造成倒地（剩余生命比例 <= 0）
			if remaining_hp_ratio <= 0.0:
				# 第一阶段：普通受击动画（后仰、下压、小角度旋转）
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
				_current_tween.tween_property(self, ^"position:x", target_x1, T).set_ease(Tween.EASE_OUT)
				_current_tween.tween_property(self, ^"position:y", target_y1, T).set_ease(Tween.EASE_IN_OUT)
				_current_tween.tween_property(self, ^"rotation", target_rot1, T).set_ease(Tween.EASE_OUT)

				# 第二阶段：从当前受击最终状态倒下（不额外后退，仅下压归零，旋转到 DOWN_ANGLE）
				_current_tween.chain()
				var fall_duration: float = DOWN_FALL_DUR_FACTOR
				var target_x2: float = target_x1  # X 保持不变，不额外后退
				var target_y2: float = _original_position.y  # 下压归零
				var target_rot2: float = _original_rotation + DOWN_ANGLE * dir
				_current_tween.tween_property(self, ^"position:x", target_x2, fall_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
				_current_tween.tween_property(self, ^"position:y", target_y2, fall_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
				_current_tween.tween_property(self, ^"rotation", target_rot2, fall_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
				# 二段动画开始时立即进入硬直状态，防止期间再次受击
				_is_down_stagger = true
				_current_tween.chain().tween_callback(_on_down_anim_finished)
			else:
				# 正常受击动画（有恢复阶段）
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
				_current_tween.tween_property(self, ^"position:x", target_x, T).set_ease(Tween.EASE_OUT)
				_current_tween.tween_property(self, ^"position:y", target_y, T).set_ease(Tween.EASE_IN_OUT)
				_current_tween.tween_property(self, ^"rotation", target_rot, T).set_ease(Tween.EASE_OUT)
				# 恢复阶段，根据剩余生命比例延长恢复时间（范围 1.0 到 RECOVER_PENALTY_MAX_MULTIPLIER）
				var t: float = clampf(remaining_hp_ratio, 0.0, 1.0)
				var recover_multiplier: float = 1.0 + (RECOVER_PENALTY_MAX_MULTIPLIER - 1.0) * (1.0 - t)
				_current_tween.chain()
				_current_tween.tween_property(self, ^"position:x", _original_position.x, RECOVER_X_FACTOR * T * recover_multiplier).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
				_current_tween.tween_property(self, ^"position:y", _original_position.y, RECOVER_Y_FACTOR * T * recover_multiplier).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
				_current_tween.tween_property(self, ^"rotation", _original_rotation, RECOVER_ROT_FACTOR * T * recover_multiplier).set_ease(Tween.EASE_IN)
				_current_tween.chain().tween_callback(_on_physical_anim_finished)
		# 闪红效果
		if character and character.material is ShaderMaterial:
			ShaderEffectsUtils.flash_color(character, Color.RED, flash_duration, 1.0)
	# 魔法受击（MP伤害，仅闪蓝）
	elif mp_damage > 0:
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
	# 清除硬直状态，杀死当前动画（如果有）
	_is_down_stagger = false
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	_current_tween = create_tween()
	# 根据剩余生命比例计算速度因子：剩余越少，站起来越慢（因子越大）
	var sink_factor: float = 1.0 / max(0.1, remaining_hp_ratio)
	sink_factor = clampf(sink_factor, 1.0, RISE_SINK_MAX_FACTOR)
	# 1. 下沉 + 旋转回正（同时进行，但时长各自独立）
	var sink_duration: float = RISE_BASE_DURATION * RISE_SINK_DURATION_FACTOR * sink_factor
	var rot_duration: float = RISE_BASE_DURATION * RISE_ROT_DURATION_FACTOR * sink_factor
	var target_y_down: float = _original_position.y + RISE_SINK_DISTANCE
	var target_rot_down: float = _original_rotation
	_current_tween.set_parallel(true)
	_current_tween.tween_property(self, ^"position:y", target_y_down, sink_duration).set_ease(Tween.EASE_IN)
	_current_tween.tween_property(self, ^"rotation", target_rot_down, rot_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# 2. 起身恢复到正常高度（稍快于下沉）
	var up_duration: float = RISE_BASE_DURATION * RISE_UP_DURATION_FACTOR * sink_factor
	_current_tween.chain()
	_current_tween.tween_property(self, ^"position:y", _original_position.y, up_duration).set_ease(Tween.EASE_OUT)
	# 3. 走回原位（水平归位，最后一步）
	var walk_duration: float = RISE_BASE_DURATION * RISE_WALK_DURATION_FACTOR * sink_factor
	_current_tween.tween_property(self, ^"position:x", _original_position.x, walk_duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
	_current_tween.chain().tween_callback(_on_recover_from_down_finished)
	# 期间将角色帧设为正常
	if character is Sprite2D:
		character.frame = 0


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
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null
		_current_hp_damage = 0
	position = _original_position
	rotation = _original_rotation
	if character and character is Sprite2D:
		character.frame = 0
	# 注意：硬直状态不受停止动画影响，需治疗解除


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
