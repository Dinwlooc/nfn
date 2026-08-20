## 局部粒子管理器，负责动态创建并发射失血粒子和升级特效粒子。
## 所有粒子节点在发射完成后自动销毁。
extends Node2D

const C = preload("status_constants.gd")

## ---- 发射器 ----
var _hit_emitter: GPUParticles2D = null
var _bleed_emitter: GPUParticles2D = null
var _levelup_emitter: GPUParticles2D = null

func _ready() -> void:
	_hit_emitter = _create_blood_particle()
	_hit_emitter.emitting = false
	add_child(_hit_emitter)
	_bleed_emitter = _create_bleed_particle()
	_bleed_emitter.emitting = false
	add_child(_bleed_emitter)
	_levelup_emitter = _create_levelup_particle()
	_levelup_emitter.emitting = false
	add_child(_levelup_emitter)

## 发射受击失血粒子（单点喷射）
func emit_blood_hit(global_pos: Vector2, hp_loss: int, hp_ratio: float) -> void:
	if hp_loss <= 0 or not _hit_emitter:
		return
	var count: int = int(lerp(float(C.HIT_COUNT_MIN), float(C.HIT_COUNT_MAX), clamp(float(hp_loss) / 20.0, 0.0, 1.0)))
	count = clamp(count, C.HIT_COUNT_MIN, C.HIT_COUNT_MAX)
	var speed_min: float = lerp(C.HIT_SPEED_MIN_MIN, C.HIT_SPEED_MIN_MAX, 1.0 - hp_ratio)
	var speed_max: float = lerp(C.HIT_SPEED_MAX_MIN, C.HIT_SPEED_MAX_MAX, 1.0 - hp_ratio)
	var spread: float = lerp(C.HIT_SPREAD_MIN, C.HIT_SPREAD_MAX, 1.0 - hp_ratio)
	_configure_and_emit(_hit_emitter, global_pos, count, speed_min, speed_max, spread, Vector3(1.0, 0.0, 0.0))

## 井喷粒子（血量归零时最大量喷射，速度最小值归零）
func emit_blood_gush(global_pos: Vector2) -> void:
	if not _hit_emitter:
		return
	var count: int = C.HIT_COUNT_MAX
	var speed_min: float = 0.0
	var speed_max: float = C.HIT_SPEED_MAX_MAX
	var spread: float = C.HIT_SPREAD_MAX
	_configure_and_emit(_hit_emitter, global_pos, count, speed_min, speed_max, spread, Vector3(1.0, 0.0, 0.0))

## 单次流血发射（只选一个块）
func emit_blood_bleed_single(global_pos: Vector2, direction: int, hp_ratio: float) -> void:
	if not _bleed_emitter:
		return
	var count: int = int(lerp(float(C.BLEED_COUNT_MIN), float(C.BLEED_COUNT_MAX), 1.0 - hp_ratio))
	count = clamp(count, C.BLEED_COUNT_MIN, C.BLEED_COUNT_MAX)
	var speed: float = lerp(C.BLEED_SPEED_MIN, C.BLEED_SPEED_MAX, 1.0 - hp_ratio)
	var spread: float = C.BLEED_SPREAD
	var dir_vec: Vector3 = Vector3(float(direction), -1.5, 0.0)
	_configure_and_emit(_bleed_emitter, global_pos, count, speed * 0.5, speed, spread, dir_vec)

## 发射升级特效粒子（在最后一个战意格位置，外部已传位置）
func emit_level_up(global_pos: Vector2) -> void:
	if not _levelup_emitter:
		return
	_levelup_emitter.global_position = global_pos
	_levelup_emitter.restart()

## ---- 内部辅助 ----
func _configure_and_emit(emitter: GPUParticles2D, global_pos: Vector2, count: int, min_speed: float, max_speed: float, spread: float, direction: Vector3) -> void:
	emitter.global_position = global_pos + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	emitter.amount = count
	var mat: ParticleProcessMaterial = emitter.process_material as ParticleProcessMaterial
	if mat:
		mat.initial_velocity_min = min_speed
		mat.initial_velocity_max = max_speed
		mat.spread = spread
		mat.direction = direction
	emitter.restart()

## ---- 工厂方法（均使用 Core 的 ParticleFactory） ----
func _create_blood_particle() -> GPUParticles2D:
	var gradient: Gradient = Gradient.new()
	gradient.colors = [Color.RED, Color.DARK_RED]
	gradient.offsets = [0.0, 1.0]
	var color_ramp: GradientTexture1D = GradientTexture1D.new()
	color_ramp.gradient = gradient

	var config: ParticleConfig = ParticleConfig.new()
	config.direction = Vector3(1.0, 0.0, 0.0)
	config.spread = 30.0
	config.gravity = C.BLOOD_GRAVITY
	config.velocity_min = 40.0
	config.velocity_max = 150.0
	config.color_ramp = color_ramp
	config.scale_min = C.BLOOD_PARTICLE_SIZE
	config.scale_max = C.BLOOD_PARTICLE_SIZE
	return ParticleFactory.create_particles(1, C.BLOOD_LIFETIME, config)

func _create_bleed_particle() -> GPUParticles2D:
	var gradient: Gradient = Gradient.new()
	gradient.colors = [Color.RED, Color.DARK_RED]
	gradient.offsets = [0.0, 1.0]
	var color_ramp: GradientTexture1D = GradientTexture1D.new()
	color_ramp.gradient = gradient

	var config: ParticleConfig = ParticleConfig.new()
	config.direction = Vector3(1.0, 0.0, 0.0)
	config.spread = 30.0
	config.gravity = C.BLOOD_GRAVITY
	config.velocity_min = 40.0
	config.velocity_max = 150.0
	config.color_ramp = color_ramp
	config.scale_min = C.BLOOD_PARTICLE_SIZE
	config.scale_max = C.BLOOD_PARTICLE_SIZE
	config.damping_min = C.BLEED_DAMPING
	config.damping_max = C.BLEED_DAMPING
	return ParticleFactory.create_particles(1, C.BLEED_LIFETIME, config)

func _create_levelup_particle() -> GPUParticles2D:
	var gradient: Gradient = Gradient.new()
	gradient.colors = [Color(0.6, 0.0, 0.8), Color(1.0, 1.0, 1.0)]
	gradient.offsets = [0.0, 1.0]
	var color_ramp: GradientTexture1D = GradientTexture1D.new()
	color_ramp.gradient = gradient

	var scale_curve: Curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(0.4, 0.9))
	scale_curve.add_point(Vector2(0.7, 0.7))
	scale_curve.add_point(Vector2(1.0, 0))
	var scale_texture: CurveTexture = CurveTexture.new()
	scale_texture.curve = scale_curve

	var config: ParticleConfig = ParticleConfig.new()
	config.direction = Vector3(0.0, -1.0, 0.0)
	config.spread = 180.0
	config.gravity = Vector3.ZERO
	config.velocity_min = C.LEVELUP_MIN_SPEED
	config.velocity_max = C.LEVELUP_MAX_SPEED
	config.color_ramp = color_ramp
	config.scale_min = C.LEVELUP_PARTICLE_SCALE_MIN
	config.scale_max = C.LEVELUP_PARTICLE_SCALE_MAX
	config.scale_curve = scale_texture
	config.damping_min = C.LEVELUP_DAMPING
	config.damping_max = C.LEVELUP_DAMPING
	return ParticleFactory.create_particles(C.LEVELUP_PARTICLE_COUNT, C.LEVELUP_LIFETIME, config)
