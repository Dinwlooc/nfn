extends ItemCounterArea
class_name RenderAreaDiscard

func  _init() -> void:
	area_name = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.DISCARD]
	pack_type = CardPack.get_class_name_static()
