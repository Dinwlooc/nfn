extends Area
class_name UnorderedArea
## 无序区域实现

var _unordered_pool: Dictionary[int, Card] = {}

func cards_add(new_cardpool: Array[Card]) -> void:
	for card in new_cardpool:
		_unordered_pool[card.id] = card
		area_card_added.emit(card,self)

func remove_cards_by_ids(ids: PackedInt32Array) -> Array[Card]:
	var removed: Array[Card] = []
	for id in ids:
		if _unordered_pool.has(id):
			var card:Card = _unordered_pool[id]
			removed.append(card)
			area_card_removed.emit(card)
			_unordered_pool.erase(id)
	return removed

func card_count() -> int:
	return _unordered_pool.size()

func get_card_by_id(card_id: int) -> Card:
	return _unordered_pool.get(card_id, null)

func get_all_cards() -> Array[Card]:
	return _unordered_pool.values()

func get_card_ids() -> PackedInt32Array:
	return _unordered_pool.keys()
