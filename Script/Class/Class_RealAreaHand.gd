extends RealArea
class_name RealAreaHand

func ready_expand()->void:
	area_name = "areahand"
	GlobalConsole.register_realarea("areahand",self)
	pass
