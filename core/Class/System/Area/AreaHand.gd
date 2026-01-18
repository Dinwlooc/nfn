extends UnorderedArea
class_name AreaHand

func _init_expand()->void:
	area_name = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.HAND]
	is_private_visible = true
