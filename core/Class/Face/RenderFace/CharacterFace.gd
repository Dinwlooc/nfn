## 角色表现基类：受击/起身动画与水平镜像的钩子契约。
## 本基类承载一次性演出通道：演出可被事件重复触发，由实现方的互斥门与补间槽位拦重复，不做状态差量。
extends Control
class_name CharacterFace

#==hooks==
## 播放受击动画钩子（由子类实现）。
## @hook
func play_damage_animation(hp_damage: int, mp_damage: int, remaining_hp_ratio: float = 1.0) -> void:
	pass
## 停止当前受击动画钩子（由子类实现）。
## @hook
func stop_damage_animation() -> void:
	pass
## 设置水平镜像钩子（由子类实现）。
## @hook
func set_mirrored(flip_h: bool) -> void:
	pass
