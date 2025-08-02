extends RefCounted
class_name CardManager


var next_id: int = 0  # 下一个可用的卡牌ID

# 为单张卡牌分配ID
func assign_id(card: Card) -> void:
	card.data["id"] = next_id
	next_id += 1

# 为卡牌数组分配ID
func assign_ids_to_cards(cards: Array[Card]) -> void:
	for card in cards:
		assign_id(card)

# 创建新卡牌并分配ID
func create_new_card(template_path: String, suit: String) -> Card:
	var card_template = load(template_path)
	if card_template:
		var new_card = card_template.duplicate()
		new_card.set_suit(suit)
		assign_id(new_card)
		return new_card
	else:
		push_error("Failed to create card from template: " + template_path)
		return null

func create_new_cards_all_suit(template_path: String) -> Array[Card]:
	var cards: Array[Card] = []
	var card_template:Card = load(template_path)
	for suit in ["Spade", "Heart", "Diamond", "Club"]:
		var card:Card = card_template.duplicate().set_suit(suit)
		assign_id(card)
		if card:
			cards.append(card)
	return cards

# 加载所有预设卡牌
func load_all_cards() -> Array[Card]:
	var card_templates = GlobalConfig.get_cards_list()
	var all_cards: Array[Card] = []
	for template_path in card_templates:
		all_cards.append_array(create_new_cards_all_suit(template_path))
	return all_cards
