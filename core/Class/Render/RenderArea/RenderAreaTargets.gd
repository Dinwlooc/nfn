extends RenderArea
class_name RenderAreaTargets

func ready_expand()->void:
	area_name = DefaultArea.TARGETS
	GlobalRegistry.register_renderarea(area_name,self)
	pass
	
