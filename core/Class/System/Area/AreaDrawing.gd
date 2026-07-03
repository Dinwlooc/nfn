extends OrderedArea
class_name AreaDrawing

func _init(_player: Player = Player.PUBLIC_PLAYER) -> void:
	super._init(_player)
	area_name = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.DRAWING]
	visibility = Visibility.INVISIBLE
