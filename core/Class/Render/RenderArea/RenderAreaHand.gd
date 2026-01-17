extends ItemRenderArea
class_name RenderAreaHand

func ready_expand()->void:
	area_name = DefaultArea.HAND
	pack_type = CardPack.get_class_name_static()
