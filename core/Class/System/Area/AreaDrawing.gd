extends OrderedArea
class_name AreaDrawing

func _init_expand()->void:
	area_name = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.DRAWING]
	visibility = Visibility.INVISIBLE

func drawing()->void:
	pass

func user_signal()-> void:
	pass
