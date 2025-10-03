extends Area
class_name AreaHand

func _init_expand()->void:
	area_name = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.HAND]
	mode = AreaMode.UNORDERED

func play()->void:
	pass
	#打出手牌的方法。
func user_signal()-> void:
	pass
