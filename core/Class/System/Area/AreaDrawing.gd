extends OrderedArea
class_name AreaDrawing

## 构造：设定区域名为牌堆
func _init(_player: Player = Player.PUBLIC_PLAYER) -> void:
	super._init(_player)
	area_name = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.DRAWING]
	visibility = Visibility.INVISIBLE
