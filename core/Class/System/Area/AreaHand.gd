extends UnorderedArea
class_name AreaHand

func _init_expand()->void:
	area_name = GlobalConstants.DefaultArea.HAND
	is_private_visible = true
	area_card_added.connect(_on_area_card_added)

func _on_area_card_added(card:Card)->void:
	card.set_player(player)
