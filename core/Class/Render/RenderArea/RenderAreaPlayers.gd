extends RenderArea
class_name RenderAreaTargets

func ready_expand()->void:
	area_name = DefaultArea.PLAYERS
	GlobalRegistry.register_renderarea(area_name,self)
	pass
	
