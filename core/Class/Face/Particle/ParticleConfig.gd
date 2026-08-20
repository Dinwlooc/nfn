## 粒子配置数据类（Core 层）
## 纯数据载体，无副作用，所有字段均有默认值。
## 提供原子装配方法，支持链式调用。
extends RefCounted
class_name ParticleConfig

## 粒子初始方向（3D向量，Z 轴在 2D 中无效）
var direction: Vector3 = Vector3(1.0, 0.0, 0.0)
## 扩散角度（度）
var spread: float = 30.0
## 重力加速度（3D向量）
var gravity: Vector3 = Vector3.ZERO
## 最小初始速度
var velocity_min: float = 40.0
## 最大初始速度
var velocity_max: float = 40.0
## 颜色渐变纹理（用于粒子生命周期内变色）
var color_ramp: GradientTexture1D = null
## 粒子最小缩放
var scale_min: float = 0.0
## 粒子最大缩放
var scale_max: float = 1.0
## 缩放曲线纹理（控制粒子生命周期内大小变化）
var scale_curve: CurveTexture = null
## 速度阻尼最小值（每秒速度减少量）
var damping_min: float = 0.0
## 速度阻尼最大值（每秒速度减少量）
var damping_max: float = 0.0

## 装配：设置方向
func set_direction(new_direction: Vector3) -> ParticleConfig:
	direction = new_direction
	return self

## 装配：设置扩散角度
func set_spread(new_spread: float) -> ParticleConfig:
	spread = new_spread
	return self

## 装配：设置重力
func set_gravity(new_gravity: Vector3) -> ParticleConfig:
	gravity = new_gravity
	return self

## 装配：设置速度范围，若 max 未提供则与 min 相同（非随机）
func set_velocity(min_speed: float, max_speed: float = min_speed) -> ParticleConfig:
	velocity_min = min_speed
	velocity_max = max_speed
	return self

## 装配：设置颜色渐变，传入 Gradient 自动创建 GradientTexture1D
func set_color_ramp_from_gradient(gradient: Gradient) -> ParticleConfig:
	var tex: GradientTexture1D = GradientTexture1D.new()
	tex.gradient = gradient
	color_ramp = tex
	return self

## 装配：直接设置颜色渐变纹理
func set_color_ramp_texture(tex: GradientTexture1D) -> ParticleConfig:
	color_ramp = tex
	return self

## 装配：设置粒子缩放范围，若 max 未提供则与 min 相同
func set_scale(min_scale: float, max_scale: float = min_scale) -> ParticleConfig:
	scale_min = min_scale
	scale_max = max_scale
	return self

## 装配：设置缩放曲线，传入 Curve 自动创建 CurveTexture
func set_scale_curve_from_curve(curve: Curve) -> ParticleConfig:
	var tex: CurveTexture = CurveTexture.new()
	tex.curve = curve
	scale_curve = tex
	return self

## 装配：直接设置缩放曲线纹理
func set_scale_curve_texture(tex: CurveTexture) -> ParticleConfig:
	scale_curve = tex
	return self

## 装配：设置阻尼范围，若 max 未提供则与 min 相同
func set_damping(min_damping: float, max_damping: float = min_damping) -> ParticleConfig:
	damping_min = min_damping
	damping_max = max_damping
	return self
