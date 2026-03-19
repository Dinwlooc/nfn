extends Area
class_name OrderedArea
## 有序区域实现

var _ordered_pool: Array[Card] = []
var _card_id_to_index: Dictionary = {}

func cards_add(new_cardpool: Array[Card]) -> void:
	var start_index = _ordered_pool.size()
	_ordered_pool.resize(_ordered_pool.size()+new_cardpool.size())
	for i in range(new_cardpool.size()):
		var card:Card = new_cardpool[i]
		_ordered_pool.set(start_index + i,card)
		_card_id_to_index[card.id] = start_index + i
		area_card_added.emit(card)

func remove_cards_by_ids(ids: PackedInt32Array) -> Array[Card]:
	var indices = PackedInt32Array()
	for id in ids:
		if _card_id_to_index.has(id):
			indices.append(_card_id_to_index[id])
	return remove_cards_at_indices(indices)

func remove_cards_at_indices(indices: PackedInt32Array) -> Array[Card]:
	if indices.is_empty():
		return []
	var removed: Array[Card] = []
	var min_index = _ordered_pool.size()
	for index in indices:
		if index < 0 or index >= _ordered_pool.size() or _ordered_pool[index] == null:
			continue
		min_index = min(min_index, index)
		var card:Card = _ordered_pool[index]
		removed.append(_ordered_pool[index])
		_card_id_to_index.erase(card.id)
		_ordered_pool[index] = null
		area_card_removed.emit(card)
		if min_index < _ordered_pool.size():
			_compress_ordered_pool(min_index)
	if removed:
		after_cards_removed.emit()
	return removed

func remove_top_cards(count: int) -> Array[Card]:
	var removed: Array[Card] = []
	count = min(count, card_count())
	var start_index = max(0, _ordered_pool.size() - count)
	removed = _ordered_pool.slice(start_index, _ordered_pool.size())
	_ordered_pool.resize(_ordered_pool.size() - count)
	for card in removed:
		_card_id_to_index.erase(card.id)
		area_card_removed.emit(card)
	if removed:
		after_cards_removed.emit()
	return removed

func card_count() -> int:
	return _ordered_pool.size()

func get_card_by_id(card_id: int) -> Card:
	if _card_id_to_index.has(card_id):
		return _ordered_pool[_card_id_to_index[card_id]]
	return null

func get_all_cards() -> Array[Card]:
	return _ordered_pool.duplicate()

func get_card_ids() -> Array[int]:
	var ids: Array[int] = []
	for card in _ordered_pool:
		ids.append(card.id)
	return ids

func shuffle_card_pool() -> void:
	_ordered_pool.shuffle()
	_rebuild_index_map()

func get_cards_at_indices(indices: PackedInt32Array) -> Array[Card]:
	var result: Array[Card] = []
	for index in indices:
		if index >= 0 and index < _ordered_pool.size() and _ordered_pool[index] != null:
			result.append(_ordered_pool[index])
	return result

func get_top_cards(count: int) -> Array[Card]:
	var result: Array[Card] = []
	count = min(count, card_count())
	var start_index = max(0, _ordered_pool.size() - count)
	for i in range(start_index, _ordered_pool.size()):
		if _ordered_pool[i] != null:
			result.append(_ordered_pool[i])
	return result

# 内部方法
func _rebuild_index_map() -> void:
	_card_id_to_index.clear()
	for idx in range(_ordered_pool.size()):
		_card_id_to_index[_ordered_pool[idx].id] = idx

func _compress_ordered_pool(start_index: int) -> void:
	var write_index = start_index
	for read_index in range(start_index, _ordered_pool.size()):
		if _ordered_pool[read_index] != null:
			if write_index != read_index:
				_ordered_pool[write_index] = _ordered_pool[read_index]
				_card_id_to_index[_ordered_pool[read_index].id] = write_index
			write_index += 1
	_ordered_pool.resize(write_index)
