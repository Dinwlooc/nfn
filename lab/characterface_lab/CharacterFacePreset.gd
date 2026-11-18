## 角色受击演出的操作参数预设：一次调度 CharacterFace 所需的全部输入。
## 预设即本资源的一个文件；操作参数不保存，运行期改动会被预设覆盖。
extends Resource
class_name CharacterFacePreset

#==字段==
## 生命伤害（负值表示治疗）
@export var hp_damage: int = 0
## 魔法伤害
@export var mp_damage: int = 0
## 剩余生命比例（0..1）
@export var remaining_ratio: float = 1.0
