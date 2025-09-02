extends RenderArea
class_name RenderAreaHand

func ready_expand()->void:
	area_name = DefaultArea.HAND
	GlobalRegistry.register_renderarea(area_name,self)
	selected.connect(quickly_select_the_target)
	pass

func quickly_select_the_target():
	var areatargets = GlobalRegistry.get_renderarea(DefaultArea.TARGETS)
	if !areatargets:
		return
	if get_selected_cards().size() == 1 && get_selected_cards()[0].data.type == RenderCard.DefaultType.ATTACK && areatargets.card_pool.size() > 0 && areatargets.get_selected_cards().size() == 0:
		areatargets.on_select(0)
	pass
