## 粒子工厂（Core 层）
## 全局类，提供纯静态方法创建或配置 GPUParticles2D 节点。
extends RefCounted
class_name ParticleFactory

## 共享的白色方形纹理（全项目复用）
static var _shared_texture: ImageTexture = _create_shared_texture()
## 创建共享纹理（2x2 白色方形）
static func _create_shared_texture() -> ImageTexture:
	var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)
## 创建或重新配置粒子节点
## @param amount: 粒子数量
## @param lifetime: 粒子生命周期（秒）
## @param config: 粒子配置（ParticleConfig 实例）
## @param particle: 可选，若传入现有 GPUParticles2D，则复用并重新配置它；否则新建
## @param texture: 可选，自定义纹理，默认使用共享白色纹理
## @return 配置好的 GPUParticles2D
static func create_particles(amount: int, lifetime: float, config: ParticleConfig, particles: GPUParticles2D = GPUParticles2D.new(), texture: Texture2D = _shared_texture) -> GPUParticles2D:
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.texture = texture
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
	if config.damping_min > 0 or config.damping_max > 0:
		mat.damping_min = config.damping_min
		mat.damping_max = config.damping_max
	particles.process_material = mat
	return particles
