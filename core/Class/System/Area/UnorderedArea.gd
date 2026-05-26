## 无序区域实现
extends Area
class_name UnorderedArea

var _unordered_pool: Dictionary[int, Card] = {}

func cards_add(new_cardpool: Array[Card]) -> void:
	for card in new_cardpool:
		_unordered_pool[card.id] = card
		card.set_area(self)
		area_card_added.emit(card, self)

func remove_cards_by_ids(ids: PackedInt32Array) -> Array[Card]:
	var removed: Array[Card] = []
	for id in ids:
		if _unordered_pool.has(id):
			var card: Card = _unordered_pool[id]
			removed.append(card)
			area_card_removed.emit(card, self)
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

func is_empty() -> bool:
	return _unordered_pool.is_empty()

## 随机获取指定数量的卡牌（不移除）
## 若 count >= 总卡牌数，则返回全部卡牌数组
func get_top_cards(count: int) -> Array[Card]:
	if count <= 0:
		return []
	var total: int = card_count()
	if count >= total:
		return get_all_cards()
	var ids: PackedInt32Array = get_card_ids()
	# 随机打乱 ID 顺序
	var id_list: Array[int] = Array(ids)
	id_list.shuffle()
	var selected_ids: PackedInt32Array = PackedInt32Array(id_list.slice(0, count))
	return get_cards_by_ids(selected_ids)

## 随机移除指定数量的卡牌（顶端移除，即随机移除）
## 若 count >= 总卡牌数，则直接移除全部并返回
func remove_top_cards(count: int) -> Array[Card]:
	if count <= 0:
		return []
	var total: int = card_count()
	if count >= total:
		# 移除所有卡牌
		var all_ids: PackedInt32Array = get_card_ids()
		return remove_cards_by_ids(all_ids)
	# 随机选择 count 张卡牌移除
	var ids: PackedInt32Array = get_card_ids()
	var id_list: Array[int] = Array(ids)
	id_list.shuffle()
	var selected_ids: PackedInt32Array = PackedInt32Array(id_list.slice(0, count))
	return remove_cards_by_ids(selected_ids)
