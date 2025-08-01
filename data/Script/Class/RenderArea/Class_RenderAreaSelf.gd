extends RenderArea
class_name RenderAreaSelf

func ready_expand()->void:
	area_name = "areaself"
	GlobalConsole.register_renderarea("areaself",self)
	pass
