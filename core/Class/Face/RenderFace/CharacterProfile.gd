## 角色主体信息定义（全局资源）
## 包含角色的标识、视觉参数、受击表现修正包和帧索引，供动画系统使用。
class_name CharacterProfile
extends Resource

## ==================== 角色标识 ====================
## 角色代码名（如 &"nfn:mizukagami"），与系统数据层玩家数据包的名称对齐
@export var character_name: StringName = &""
## ==================== 精灵图配置 ====================
## 角色主体精灵图（Texture2D）
@export var texture: Texture2D = null
## 精灵图水平分割数（即列数）
@export var hframes: int = 1
## 精灵图垂直分割数（即行数）
@export var vframes: int = 1
## ==================== 帧定义 ====================
## 初始受击帧（受到攻击时播放的帧索引）
@export var hit_frame: int = 1
## 初始待机帧（正常状态）
@export var idle_frame_normal: int = 0
## 初始待机帧（轻伤状态，预留）
@export var idle_frame_light: int = 0
## 初始待机帧（重伤状态，预留）
@export var idle_frame_heavy: int = 0
## 初始死亡帧（预留）
@export var death_frame: int = 0
## 初始起身帧（预留）
@export var rise_frame: int = 0
## ==================== 物理因子 ====================
## 身高因子（预留）
@export var height_factor: float = 1.0
## ==================== 受击表现 ====================
## 受击表现修正包（未配置时按全 100 处理，即保持基准观感）
@export var hit_pack: CharacterHitPack = null
## ==================== 颜色 ====================
## 主色彩（预留）
@export var primary_color: Color = Color.WHITE
## 副色彩（预留）
@export var secondary_color: Color = Color.WHITE
