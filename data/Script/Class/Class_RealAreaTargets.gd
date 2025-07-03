extends RealArea
class_name RealAreaTargets

func ready_expand()->void:
	area_name = "areatargets"
	GlobalConsole.register_realarea("areatargets",self)
	pass
	
