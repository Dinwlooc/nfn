extends RealArea
class_name RealAreaSelf

func ready_expand()->void:
	area_name = "areaself"
	GlobalConsole.register_realarea("areaself",self)
	pass
