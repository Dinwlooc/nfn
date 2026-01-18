extends ItemRenderArea
class_name RenderAreaPlayers

func ready_expand()->void:
	area_name = DefaultArea.PLAYERS
	pack_type = PlayerPack.get_class_name_static()
