## 卡牌管理器，负责卡牌实例的创建、ID分配与全局索引。
extends RefCounted
class_name CardsManager

#=== Variables ===
## 下一个可用的卡牌 ID（从 0 开始，由 Card 分配）
var next_id: int = 0
## 所有卡牌实例数组（按 ID 索引）
var card_instances: Array[Card] = []

#=== Constants ===
## 预定义的花色列表（使用 Card.Suit 枚举）
const SUITS: Array[int] = [
	Card.Suit.SPADE,
	Card.Suit.HEART,
	Card.Suit.DIAMOND,
	Card.Suit.CLUB
]

#=== Public Methods ===
## 通过 ID 获取卡牌实例
## @pure
func get_card_by_id(card_id: int) -> Card:
	if card_id >= 0 and card_id < next_id:
		return card_instances[card_id]
	return null
## 为单张卡牌分配 ID（添加到数组末尾）
## @side_effect
func assign_id(card: Card) -> void:
	if next_id == card_instances.size():
		card_instances.append(card)
	else:
		push_warning("Unexpected ID assignment: " + str(next_id) + " but array size is " + str(card_instances.size()))
	_add_card_to_array(card, next_id)
	next_id += 1
## 批量分配 ID 到卡牌数组（优化版本，预先调整数组大小）
## @side_effect
func assign_ids_to_cards(cards: Array[Card]) -> void:
	if cards.is_empty():
		return
	_ensure_capacity(cards.size())
	_add_cards_to_array(cards, next_id)
	next_id += cards.size()
## 创建新卡牌并分配 ID
## @side_effect
func create_new_card(template_path: String, suit: int) -> Card:
	var card: Card = _create_card_instance(template_path, suit)
	if card:
		assign_id(card)
	return card
## 创建所有花色的手牌（四种花色）
## @side_effect
func create_handcards_all_suit(template_path: String) -> Array[Card]:
	var cards: Array[Card] = []
	var card_data: CardData = load(template_path) as CardData
	if not card_data:
		push_error("Failed to load card template: " + template_path)
		return cards
	_ensure_capacity(SUITS.size())
	for suit in SUITS:
		var card: Card = Card.new(card_data)
		card.set_suit(suit)
		cards.append(card)
	for i in range(cards.size()):
		_add_card_to_array(cards[i], next_id + i)
	next_id += SUITS.size()
	return cards
## 加载所有卡牌（从 GlobalConfig 获取模板路径，为每个模板生成四种花色）
## @side_effect
func load_all_cards() -> Array[Card]:
	var card_templates: PackedStringArray = GlobalConfig.get_cards_list()
	var all_cards: Array[Card] = []
	var total_cards: int = card_templates.size() * SUITS.size()
	_ensure_capacity(total_cards)
	for template_path: String in card_templates:
		var card_data: CardData = load(template_path) as CardData
		if not card_data:
			push_error("Failed to load card template: " + template_path)
			continue
		for suit in SUITS:
			var card: Card = Card.new(card_data)
			card.set_suit(suit)
			_add_card_to_array(card, next_id)
			all_cards.append(card)
			next_id += 1
	return all_cards
## 清除所有卡牌
## @internal
func clear_all_cards() -> void:
	card_instances.clear()
	next_id = 0
## 获取所有卡牌 ID（0 到 next_id-1 的连续数组）
## @pure
func get_all_card_ids() -> Array[int]:
	var ids: Array[int] = []
	for i in range(next_id):
		ids.append(i)
	return ids
## 获取所有卡牌实例
## @pure
func get_all_card_instances() -> Array[Card]:
	return card_instances.slice(0, next_id)
## 检查卡牌 ID 是否存在
## @pure
func has_card_id(card_id: int) -> bool:
	return card_id >= 0 and card_id < next_id

#=== Private Methods ===
## 内部方法：将卡牌添加到数组并分配 ID
## @side_effect
func _add_card_to_array(card: Card, card_id: int) -> void:
	card.set_card_id(card_id)
	if card_id >= card_instances.size():
		card_instances.resize(card_id + 1)
	card_instances[card_id] = card
## 内部方法：批量添加卡牌到数组
## @side_effect
func _add_cards_to_array(cards: Array[Card], start_id: int) -> void:
	for i in range(cards.size()):
		_add_card_to_array(cards[i], start_id + i)
## 内部方法：确保数组容量足够
## @internal
func _ensure_capacity(additional_count: int) -> void:
	var needed_size: int = next_id + additional_count
	if needed_size > card_instances.size():
		card_instances.resize(needed_size)
## 内部方法：创建卡牌实例（不分配 ID）
## @factory
func _create_card_instance(template_path: String, suit: int) -> Card:
	var card_data: CardData = load(template_path) as CardData
	if not card_data:
		push_error("Failed to load card template: " + template_path)
		return null
	var card: Card = Card.new(card_data)
	card.set_suit(suit)
	return card
