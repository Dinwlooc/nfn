extends Control
class_name CharacterFace

## 播放受击动画（由子类实现）
func play_damage_animation(hp_damage: int, mp_damage: int, remaining_hp_ratio: float = 1.0) -> void:
	pass

## 停止当前受击动画（由子类实现）
func stop_damage_animation() -> void:
	pass

## 设置水平镜像（由子类实现）
## flip_h: true 表示水平翻转，false 表示原始方向
func set_mirrored(flip_h: bool) -> void:
	pass
