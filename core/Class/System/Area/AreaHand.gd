extends UnorderedArea
class_name AreaHand

func _init(_player: Player = Player.PUBLIC_PLAYER) -> void:
	super._init(_player)
	area_name = GlobalConstants.DefaultArea.HAND
	visibility = Visibility.PRIVATE
	area_card_added.connect(_on_area_card_added)

func _on_area_card_added(card:Card,_area:Area)->void:
	card.set_player(player)
