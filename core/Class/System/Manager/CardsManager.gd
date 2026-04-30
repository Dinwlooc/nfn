extends RefCounted
class_name CardsManager

var next_id: int = 0  # 下一个可用的卡牌ID
var card_instances: Array[Card] = []
## 预定义的花色列表，避免重复创建
const SUITS = [HandCard.Suit.SPADE, HandCard.Suit.HEART, HandCard.Suit.DIAMOND, HandCard.Suit.CLUB]
## 内部方法：将卡牌添加到数组并分配ID
func _add_card_to_array(card: Card, card_id: int) -> void:
	card.id = card_id
	card_instances[card_id] = card
## 内部方法：批量添加卡牌到数组
func _add_cards_to_array(cards: Array[Card], start_id: int) -> void:
	for i in range(cards.size()):
		_add_card_to_array(cards[i], start_id + i)
## 内部方法：确保数组容量足够
func _ensure_capacity(additional_count: int) -> void:
	var needed_size = next_id + additional_count
	if needed_size > card_instances.size():
		card_instances.resize(needed_size)
## 通过ID获取卡牌实例
func get_card_by_id(card_id: int) -> Card:
	if card_id >= 0 and card_id < next_id:
		return card_instances[card_id]
	return null
## 为单张卡牌分配ID（添加到数组末尾）
func assign_id(card: Card) -> void:
	if next_id == card_instances.size():
		card_instances.append(card)
	else:
		push_warning("Unexpected ID assignment: " + str(next_id))
	_add_card_to_array(card, next_id)
	next_id += 1
## 批量分配ID到卡牌数组（优化版本，预先调整数组大小）
func assign_ids_to_cards(cards: Array[Card]) -> void:
	if cards.is_empty():
		return
	_ensure_capacity(cards.size())
	_add_cards_to_array(cards, next_id)
	next_id += cards.size()
## 内部方法：创建卡牌实例
func _create_card_instance(template_path: String, suit: HandCard.Suit) -> HandCard:
	var card_template = load(template_path)
	if not card_template:
		push_error("Failed to load card template: " + template_path)
		return null
	var card: HandCard = card_template.duplicate()
	card.set_suit(suit)
	return card
## 创建新卡牌并分配ID
func create_new_card(template_path: String, suit: HandCard.Suit) -> Card:
	var card = _create_card_instance(template_path, suit)
	if card:
		assign_id(card)
	return card
## 创建所有花色的手牌
func create_handcards_all_suit(template_path: String) -> Array[HandCard]:
	var cards: Array[HandCard] = []
	_ensure_capacity(SUITS.size())
	var card_template = load(template_path)
	if not card_template:
		push_error("Failed to load card template: " + template_path)
		return cards
	for i in range(SUITS.size()):
		var card: HandCard = card_template.duplicate()
		card.set_suit(SUITS[i])
		cards.append(card)
	for i in range(cards.size()):
		_add_card_to_array(cards[i], next_id + i)
	next_id += SUITS.size()
	return cards
## 加载所有卡牌
func load_all_cards() -> Array[Card]:
	var card_templates:PackedStringArray = GlobalConfig.get_cards_list()
	var all_cards: Array[Card] = []
	var total_cards:int = card_templates.size() * SUITS.size()
	_ensure_capacity(total_cards)
	for template_path:String in card_templates:
		var card_template:Card = load(template_path)
		if not card_template:
			push_error("Failed to load card template: " + template_path)
			continue
		for suit in SUITS:
			var card: HandCard = card_template.duplicate()
			card.set_suit(suit)
			_add_card_to_array(card, next_id)
			all_cards.append(card)
			next_id += 1
			card._init()
	return all_cards
## 清除所有卡牌
func clear_all_cards() -> void:
	card_instances.clear()
	next_id = 0
## 获取所有卡牌ID（0到next_id-1的连续数组）
func get_all_card_ids() -> Array:
	return range(next_id)
## 获取所有卡牌实例
func get_all_card_instances() -> Array:
	return card_instances.slice(0, next_id)
## 检查卡牌ID是否存在
func has_card_id(card_id: int) -> bool:
	return card_id >= 0 and card_id < next_id
