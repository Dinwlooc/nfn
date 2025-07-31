extends RenderArea
class_name RenderAreaHand

func ready_expand()->void:
	area_name = "areahand"
	GlobalConsole.register_renderarea("areahand",self)
	pass
