extends RenderArea
class_name RenderAreaHand

func ready_expand()->void:
	area_name = DefaultArea.HAND
	GlobalRegistry.register_renderarea(area_name,self)
	pass
