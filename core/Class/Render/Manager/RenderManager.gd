extends RefCounted
class_name RenderManager

func create_card_face(card: RenderCard) -> void:
	var type_name = GlobalRegistry.get_constant_name(GlobalConstants.KEY_CARD_TYPE,card.data.type)
	var cardface:RenderCardFace = load(GlobalConfig.get_resource_path(&"cardface",type_name)).instantiate()
	if cardface:
		cardface.card = card
		card.add_child(cardface)
		card.render_requested.connect(cardface.render_update)
		cardface.data_update()

func create_cards(cards:Array[CardPack],area:RenderArea)-> void:
	var new_cards:Array[RenderCard]
	new_cards.resize(cards.size())
	var array_position = area.card_pool.size()
	for i in range(0,cards.size()):
			var new_card:RenderCard = RenderCard.new()
			new_card.area = area
			new_card.pool_id = array_position + i
			new_cards.set(i,new_card)
			area.add_child(new_card)
			area.render_requested.connect(new_card.render_update)
			new_card.data_requested.connect(create_card_face.bind(new_card))
			new_card.data_update(cards[i])
			area.card_id_to_pool_id[cards[i].id] = array_position + i
	area.cards_added.emit(new_cards)
	area.card_pool.append_array(new_cards)
	area.render_update()
