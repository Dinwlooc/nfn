extends UnorderedArea
class_name AreaDiscard

func _init_expand()->void:
	area_name = GlobalConstants.DefaultArea.DISCARD
	visibility = Visibility.PUBLIC
	area_card_added.connect(_on_area_card_added)

func _on_area_card_added(card:Card,_area:Area)->void:
	card.clear_player()
	card.clear_pack_cache()
	card.reset_card()
