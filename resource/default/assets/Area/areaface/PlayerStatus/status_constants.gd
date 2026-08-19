## 玩家状态界面与粒子效果共享的常量配置
## 所有数值均可在此统一调整

## ---- 血粒子通用 ----
const BLOOD_LIFETIME: float = 3.0
const BLOOD_GRAVITY: Vector3 = Vector3(0.0, 980.0, 0.0)
const BLOOD_PARTICLE_SIZE: float = 3.0

## ---- 受击失血参数 ----
const HIT_COUNT_MIN: int = 6
const HIT_COUNT_MAX: int = 80
const HIT_SPEED_MIN_MIN: float = 100.0
const HIT_SPEED_MIN_MAX: float = 900.0
const HIT_SPEED_MAX_MIN: float = 400.0
const HIT_SPEED_MAX_MAX: float = 800.0
const HIT_SPREAD_MIN: float = 20.0
const HIT_SPREAD_MAX: float = 180.0

## ---- 流血参数 ----
const BLEED_COUNT_MIN: int = 2
const BLEED_COUNT_MAX: int = 4
const BLEED_SPEED_MIN: float = 30.0
const BLEED_SPEED_MAX: float = 100.0
const BLEED_SPREAD: float = 30.0
const BLEED_INTERVAL_AT_50: int = 240   # 血量50%时间隔帧数
const BLEED_INTERVAL_AT_0: int = 60    # 血量0%时间隔帧数（最快）
const BLEED_SELECT_COUNT: int = 4      # 每次流血选取的最大块数

## ---- 升级粒子 ----
const LEVELUP_PARTICLE_COUNT: int = 40
const LEVELUP_LIFETIME: float = 3.2
const LEVELUP_MIN_SPEED: float = 40.0
const LEVELUP_MAX_SPEED: float = 220.0
const LEVELUP_PARTICLE_SCALE_MIN: float = 2.0    # 粒子最小尺寸
const LEVELUP_PARTICLE_SCALE_MAX: float = 6.0    # 粒子最大尺寸
const LEVELUP_DAMPING: float = 150.0             # 速度阻尼（每秒速度减少量）

## ---- HP/MP/战意颜色等UI常量（从原文件移出） ----
const COLOR_HP_CURRENT: Color = Color(0.99, 0.1, 0.0, 0.7)
const COLOR_HP_LOST: Color = Color(0.5, 0.5, 0.5, 0.7)
const COLOR_MP_CURRENT: Color = Color(0, 1.0, 1.0, 0.7)
const COLOR_MP_LOST: Color = Color(0.2, 0.2, 0.2, 0.7)
const COLOR_MORALE_ATTACK: Color = Color(0.8, 0.2, 0.8, 0.8)
const COLOR_MORALE_DEFENSE: Color = Color(0.2, 0.4, 0.8, 0.8)
const COLOR_MORALE_FULL: Color = Color(0.7, 0.3, 1.0, 0.85)

const HP_BLOCK_SCALE: float = 0.8
const HP_BLINK_DURATION: float = 0.2
const MIN_BLINK_DURATION: float = 0.05
const MP_DOTS_PER_UNIT: int = 4
const MP_BLINK_DURATION: float = 0.2
const MP_DOT_FADE_OUT_DURATION: float = 0.2
const MORALE_BLOCK_SCALE: float = 0.8
const MORALE_BLINK_DURATION: float = 0.15
const UPGRADE_REQUIREMENTS: Array[int] = [7, 12, 15, 18]
const MORALE_NEW_BLOCK_FADE_DURATION: float = 1.0
