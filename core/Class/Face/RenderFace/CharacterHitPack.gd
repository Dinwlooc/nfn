## 角色受击表现修正包（表现层资源）：受击动画的幅度与力度百分数。
## 只承载原始整型百分数（100 与基准观感一致）；幅度钳制一律由动画组件在计算时执行，
## 因为后续会引入更复杂的动画修正算法，原始数据不得被改写。
class_name CharacterHitPack
extends Resource

#==knockback==
## 击退幅度百分数（100 与基准一致；负值不改变击退方向，由动画组件钳制到 0）
@export var knockback_percent: int = 100
#==translation==
## 屈膝幅度百分数（受击平动中向下移动的幅度，100 与基准一致；负值使角色向上飘起）
@export var knee_bend_percent: int = 100
#==rotation==
## 后倾幅度百分数（受击退时的旋转幅度，100 与基准一致；0 时只保留击退与屈膝；负值使角色向前倾）
@export var lean_back_percent: int = 100
#==force==
## 膝盖力度百分数（起身垂直复位的速度，是回位时长的比例；100 与基准一致，0 时与回到水平位置同速）
@export var knee_force_percent: int = 100
## 回正力度百分数（旋转复位的速度，是回位时长的比例；100 与基准一致，0 时与回到水平位置同速）
@export var upright_force_percent: int = 100
#==speed==
## 回位速度百分数（受击后回位的速度，100 与基准一致；小于 10 由动画组件钳制到 10）
@export var recover_speed_percent: int = 100
