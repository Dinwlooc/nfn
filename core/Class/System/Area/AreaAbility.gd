extends OrderedArea
class_name AreaAbility

## 构造：设定区域名为技能区
func _init(_player: Player = Player.PUBLIC_PLAYER) -> void:
	super._init(_player)
	area_name = GlobalConstants.DefaultArea.ABILITY
