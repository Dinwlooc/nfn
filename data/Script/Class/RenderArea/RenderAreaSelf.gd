extends RenderArea
class_name RenderAreaSelf

func ready_expand()->void:
	area_name = DefaultArea.SELF
	GlobalConsole.register_renderarea(area_name,self)
	pass
