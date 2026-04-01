extends CharacterFace

## 角色Sprite节点（需手动设置或通过路径获取）
@onready var character: Sprite2D = $Character

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
## 受击最小/最大动画时长（秒）
const MIN_DURATION: float = 0.04
const MAX_DURATION: float = 0.2
## 恢复阶段时长系数（相对于T）
const RECOVER_X_FACTOR: float = 10.0
const RECOVER_Y_FACTOR: float = 7.0
const RECOVER_ROT_FACTOR: float = 5.0
## 总闪红时长系数（包含恢复）
const TOTAL_TIME_FACTOR: float = 1.0 + RECOVER_X_FACTOR

## 当前正在播放的物理受击伤害值
var _current_hp_damage: int = 0
## 当前物理受击的 Tween 实例
var _current_tween: Tween = null
## 当前水平镜像状态
var _is_mirrored: bool = false

## 缓存的初始位置（相对于父节点）
var _original_position: Vector2
## 缓存的初始旋转
var _original_rotation: float


func _ready() -> void:
	# 缓存节点初始状态，用于动画偏移和复位
	_original_position = position
	_original_rotation = rotation


## 播放受击动画（重写父类方法）
func play_damage_animation(hp_damage: int, mp_damage: int) -> void:
	# 卫语句：无有效伤害则返回
	if hp_damage <= 0 and mp_damage <= 0:
		return
	# 计算动画参数
	var factor: float = clampf(hp_damage / DAMAGE_REFERENCE, 0.0, 1.0)
	var T: float = MIN_DURATION + (MAX_DURATION - MIN_DURATION) * factor
	var flash_duration: float = TOTAL_TIME_FACTOR * T
	# 物理受击（HP伤害）
	if hp_damage > 0:
		# 若已有更严重的伤害正在播放，则跳过本次低优先级伤害
		if _current_tween != null and hp_damage >= _current_hp_damage:
			_current_tween.kill()
			_current_tween = null
			_current_hp_damage = 0
		if _current_tween == null:
			_current_hp_damage = hp_damage
			# 根据镜像决定方向（镜像时 X 位移和旋转取反）
			var dir: float = -1.0 if _is_mirrored else 1.0
			var angle: float = (MIN_ANGLE + (MAX_ANGLE - MIN_ANGLE) * factor) * dir
			var back_dist: float = (MIN_BACK_DIST + (MAX_BACK_DIST - MIN_BACK_DIST) * factor) * dir
			var down_dist: float = MIN_DOWN_DIST + (MAX_DOWN_DIST - MIN_DOWN_DIST) * factor

			# 计算目标位置和旋转（基于缓存初始值）
			var target_x: float = _original_position.x + back_dist
			var target_y: float = _original_position.y + down_dist
			var target_rot: float = _original_rotation + angle

			_current_tween = create_tween()
			_current_tween.set_parallel(true)
			# 切换到受击帧
			if character is Sprite2D:
				character.frame = 1
			# 位移 + 旋转（作用于自身，即CharacterFace节点）
			_current_tween.tween_property(self, ^"position:x", target_x, T).set_ease(Tween.EASE_OUT)
			_current_tween.tween_property(self, ^"position:y", target_y, T).set_ease(Tween.EASE_IN_OUT)
			_current_tween.tween_property(self, ^"rotation", target_rot, T).set_ease(Tween.EASE_OUT)
			# 恢复阶段（串行执行，保持原逻辑），始终归零（基于缓存初始值）
			_current_tween.chain()
			_current_tween.tween_property(self, ^"position:x", _original_position.x, RECOVER_X_FACTOR * T).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
			_current_tween.tween_property(self, ^"position:y", _original_position.y, RECOVER_Y_FACTOR * T).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_BACK)
			_current_tween.tween_property(self, ^"rotation", _original_rotation, RECOVER_ROT_FACTOR * T).set_ease(Tween.EASE_IN)
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


## 停止当前受击动画（重写父类方法）
func stop_damage_animation() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null
		_current_hp_damage = 0
	# 复位到缓存的初始位置与旋转
	position = _original_position
	rotation = _original_rotation
	if character and character is Sprite2D:
		character.frame = 0


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
