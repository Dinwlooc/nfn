extends RenderArea
class_name RenderAreaSelf

func ready_expand()->void:
	area_name = DefaultArea.SELF
	GlobalRegistry.register_renderarea(area_name,self)
	pass
