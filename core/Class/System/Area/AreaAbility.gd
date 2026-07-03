extends OrderedArea
class_name AreaAbility

func _init(_player: Player = Player.PUBLIC_PLAYER) -> void:
	super._init(_player)
	area_name = GlobalConstants.DefaultArea.ABILITY
