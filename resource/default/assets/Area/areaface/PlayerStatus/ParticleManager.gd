## 局部粒子管理器，负责动态创建并发射失血粒子和升级特效粒子。
## 所有粒子节点在发射完成后自动销毁。
extends Node2D

const C = preload("status_constants.gd")

## ---- 内部配置结构体（替代字典） ----
class ParticleConfig:
	extends RefCounted
	var direction: Vector3 = Vector3(1.0, 0.0, 0.0)
	var spread: float = 30.0
	var gravity: Vector3 = Vector3.ZERO
	var velocity_min: float = 40.0
	var velocity_max: float = 150.0
	var color_ramp: GradientTexture1D = null
	var scale_min: float = 0.0
	var scale_max: float = 1.0
	var scale_curve: CurveTexture = null

## ---- 发射器 ----
var _hit_emitter: GPUParticles2D = null
var _bleed_emitters: Array[GPUParticles2D] = []   # 4个流血发射器
var _bleed_index: int = 0
var _levelup_emitter: GPUParticles2D = null

func _ready() -> void:
	_hit_emitter = _create_blood_particle()
	_hit_emitter.emitting = false
	add_child(_hit_emitter)
	for i in 4:
		var p: GPUParticles2D = _create_blood_particle()
		p.emitting = false
		add_child(p)
		_bleed_emitters.append(p)
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

## 批量发射流血粒子（每个块独立方向）
func emit_blood_bleed_batch(positions: Array[Vector2], directions: Array[int], hp_ratio: float) -> void:
	if positions.is_empty() or _bleed_emitters.is_empty():
		return
	var count: int = min(positions.size(), _bleed_emitters.size())
	var particle_count: int = int(lerp(float(C.BLEED_COUNT_MIN), float(C.BLEED_COUNT_MAX), 1.0 - hp_ratio))
	particle_count = clamp(particle_count, C.BLEED_COUNT_MIN, C.BLEED_COUNT_MAX)
	var speed: float = lerp(C.BLEED_SPEED_MIN, C.BLEED_SPEED_MAX, 1.0 - hp_ratio)
	var spread: float = C.BLEED_SPREAD
	for i in range(count):
		var emitter: GPUParticles2D = _bleed_emitters[_bleed_index]
		_bleed_index = (_bleed_index + 1) % _bleed_emitters.size()
		var dir: float = 1.0 if directions[i] == 1 else -1.0
		var pos: Vector2 = positions[i]
		_configure_and_emit(emitter, pos, particle_count, speed * 0.5, speed, spread, Vector3(dir, -1.5, 0.0))

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

## ---- 通用粒子构造器（使用配置结构体） ----
func _create_particle(amount: int, lifetime: float, config: ParticleConfig) -> GPUParticles2D:
	var p: GPUParticles2D = GPUParticles2D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	# 白色方形纹理
	var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	p.texture = tex
	var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
	mat.direction = config.direction
	mat.spread = config.spread
	mat.gravity = config.gravity
	mat.initial_velocity_min = config.velocity_min
	mat.initial_velocity_max = config.velocity_max
	if config.color_ramp:
		mat.color_ramp = config.color_ramp
	if config.scale_min > 0 or config.scale_max > 0:
		mat.scale_min = config.scale_min
		mat.scale_max = config.scale_max
	if config.scale_curve:
		mat.scale_curve = config.scale_curve
	p.process_material = mat
	return p

## ---- 工厂方法 ----
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
	return _create_particle(1, C.BLOOD_LIFETIME, config)

func _create_levelup_particle() -> GPUParticles2D:
	# 紫色渐变至白色
	var gradient: Gradient = Gradient.new()
	gradient.colors = [Color(0.6, 0.0, 0.8), Color(1.0, 1.0, 1.0)]
	gradient.offsets = [0.0, 1.0]
	var color_ramp: GradientTexture1D = GradientTexture1D.new()
	color_ramp.gradient = gradient
	# 大小曲线（随时间缓慢收缩至初始大小的50%）
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

	var p: GPUParticles2D = _create_particle(C.LEVELUP_PARTICLE_COUNT, C.LEVELUP_LIFETIME, config)
	# 设置阻尼使速度线性衰减
	var mat: ParticleProcessMaterial = p.process_material as ParticleProcessMaterial
	if mat:
		mat.damping_max = C.LEVELUP_DAMPING
		mat.damping_min = C.LEVELUP_DAMPING
	return p
