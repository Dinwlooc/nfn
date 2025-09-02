extends RenderArea
class_name RenderAreaTargets

func ready_expand()->void:
	area_name = "areatargets"
	GlobalRegistry.register_renderarea("areatargets",self)
	pass
	
