extends RenderArea
class_name RenderAreaTargets

func ready_expand()->void:
	area_name = "areatargets"
	GlobalConsole.register_renderarea("areatargets",self)
	pass
	
