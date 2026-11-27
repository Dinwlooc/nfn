## 玩家状态界面与粒子效果共享的常量配置
## 所有数值均可在此统一调整

## ---- 血粒子通用 ----
## 血粒子寿命（秒）
const BLOOD_LIFETIME: float = 3.0
## 血粒子重力
const BLOOD_GRAVITY: Vector3 = Vector3(0.0, 980.0, 0.0)
## 血粒子尺寸
const BLOOD_PARTICLE_SIZE: float = 3.0

## ---- 受击失血参数 ----
## 单次受击粒子数下限
const HIT_COUNT_MIN: int = 6
## 单次受击粒子数上限
const HIT_COUNT_MAX: int = 80
## 初速下限的随机下界
const HIT_SPEED_MIN_MIN: float = 100.0
## 初速下限的随机上界
const HIT_SPEED_MIN_MAX: float = 900.0
## 初速上限的随机下界
const HIT_SPEED_MAX_MIN: float = 400.0
## 初速上限的随机上界
const HIT_SPEED_MAX_MAX: float = 800.0
## 扩散角下限（度）
const HIT_SPREAD_MIN: float = 20.0
## 扩散角上限（度）
const HIT_SPREAD_MAX: float = 180.0

## ---- 流血参数（单发射器） ----
## 每轮流血粒子数下限
const BLEED_COUNT_MIN: int = 1
## 每轮流血粒子数上限
const BLEED_COUNT_MAX: int = 1
## 流速下限
const BLEED_SPEED_MIN: float = 30.0
## 流速上限
const BLEED_SPEED_MAX: float = 100.0
## 扩散角（度）
const BLEED_SPREAD: float = 30.0
## 血量 50% 时的发射间隔帧数
const BLEED_INTERVAL_AT_50: int = 240   # 血量50%时间隔帧数
## 血量 0% 时的发射间隔帧数（最快）
const BLEED_INTERVAL_AT_0: int = 60     # 血量0%时间隔帧数（最快）
## 独立寿命（秒）
const BLEED_LIFETIME: float = 0.5       # 独立寿命
## 速度阻尼（每秒速度减少量）
const BLEED_DAMPING: float = 100.0      # 速度阻尼（每秒速度减少量）
## ---- 升级粒子 ----
## 升级粒子总数
const LEVELUP_PARTICLE_COUNT: int = 40
## 升级粒子寿命（秒）
const LEVELUP_LIFETIME: float = 3.2
## 最小初速
const LEVELUP_MIN_SPEED: float = 40.0
## 最大初速
const LEVELUP_MAX_SPEED: float = 220.0
## 粒子最小尺寸
const LEVELUP_PARTICLE_SCALE_MIN: float = 2.0    # 粒子最小尺寸
## 粒子最大尺寸
const LEVELUP_PARTICLE_SCALE_MAX: float = 6.0    # 粒子最大尺寸
## 速度阻尼（每秒速度减少量）
const LEVELUP_DAMPING: float = 150.0             # 速度阻尼（每秒速度减少量）
## ---- HP/MP/战意颜色等UI常量 ----
## 当前生命块颜色
const COLOR_HP_CURRENT: Color = Color(0.99, 0.1, 0.0, 0.7)
## 已失去的生命块颜色
const COLOR_HP_LOST: Color = Color(0.5, 0.5, 0.5, 0.7)
## 当前法力点颜色
const COLOR_MP_CURRENT: Color = Color(0, 1.0, 1.0, 0.7)
## 已失去的法力点颜色
const COLOR_MP_LOST: Color = Color(0.2, 0.2, 0.2, 0.7)
## 攻击战意颜色
const COLOR_MORALE_ATTACK: Color = Color(0.8, 0.2, 0.8, 0.8)
## 防御战意颜色
const COLOR_MORALE_DEFENSE: Color = Color(0.2, 0.4, 0.8, 0.8)
## 战意满层颜色
const COLOR_MORALE_FULL: Color = Color(0.7, 0.3, 1.0, 0.85)

## 生命块整体缩放
const HP_BLOCK_SCALE: float = 0.8
## 生命块闪烁时长（秒）
const HP_BLINK_DURATION: float = 0.2
## 闪烁时长下限（秒）
const MIN_BLINK_DURATION: float = 0.05
## 每个法力单位包含的点数
const MP_DOTS_PER_UNIT: int = 4
## 法力点闪烁时长（秒）
const MP_BLINK_DURATION: float = 0.2
## 法力点淡出时长（秒）
const MP_DOT_FADE_OUT_DURATION: float = 0.2
## 战意块整体缩放
const MORALE_BLOCK_SCALE: float = 0.8
## 战意块闪烁时长（秒）
const MORALE_BLINK_DURATION: float = 0.15
## 战意等级升级所需总士气阈值（按等级顺序）
const UPGRADE_REQUIREMENTS: Array[int] = [7, 12, 15, 18]
## 新战意块淡入时长（秒）
const MORALE_NEW_BLOCK_FADE_DURATION: float = 1.0

## ---- 两步渐变参数（生命值 > 50% 时使用） ----
## 闪色停留时长（秒）
const HP_TWO_STEP_FLASH_DURATION: float = 0.2
## 闪色到目标色的渐变时长（秒）
const HP_TWO_STEP_GRADIENT_DURATION: float = 0.5
