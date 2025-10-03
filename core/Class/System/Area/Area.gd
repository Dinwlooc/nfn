extends RefCounted
class_name Area
##无序模式下按索引移除和堆顶移除方法不可靠。
enum AreaMode {
	ORDERED,
	UNORDERED
}
var player: Player
var area_name: StringName
var mode: AreaMode = AreaMode.ORDERED
signal area_cards_add(new_cardpool)
var _ordered_pool: Array[Card] = []           # 有序卡池
var _card_id_to_index: Dictionary = {}        # ID到索引的映射
var _unordered_pool: Dictionary[int,Card] = {}          # ID到卡牌的映射

func _init(_player:Player = null, initial_mode: AreaMode = AreaMode.ORDERED) -> void:
	player = _player
	mode = initial_mode
	area_cards_add.connect(send_cards_add)
	_init_expand()
func _init_expand() -> void:
	pass
func shuffle_card_pool() -> void:
	match mode:
		AreaMode.ORDERED:
			_ordered_pool.shuffle()  # 洗牌后索引已变，但未更新 _card_id_to_index!
			_rebuild_index_map()
func _rebuild_index_map() -> void:
	_card_id_to_index.clear()
	for idx in range(_ordered_pool.size()):
		_card_id_to_index[_ordered_pool[idx].id] = idx
func cards_add(new_cardpool: Array[Card]) -> void:
	match mode:
		AreaMode.ORDERED:
			var start_index = _ordered_pool.size()
			_ordered_pool.append_array(new_cardpool)
			for i in range(new_cardpool.size()):
				var card = new_cardpool[i]
				_card_id_to_index[card.id] = start_index + i
		AreaMode.UNORDERED:
			for card in new_cardpool:
				_unordered_pool[card.id] = card
	area_cards_add.emit(new_cardpool)
func remove_cards_by_ids(ids: PackedInt32Array) -> Array[Card]:
	var removed: Array[Card] = []
	match mode:
		AreaMode.ORDERED:
			var indices = PackedInt32Array()
			for id in ids:
				if _card_id_to_index.has(id):
					indices.append(_card_id_to_index[id])
			removed = remove_cards_at_indices(indices)
		AreaMode.UNORDERED:
			for id in ids:
				if _unordered_pool.has(id):
					removed.append(_unordered_pool[id])
					_unordered_pool.erase(id)
	return removed
func remove_cards_at_indices(indices: PackedInt32Array) -> Array[Card]:
	var removed: Array[Card] = []
	match mode:
		AreaMode.ORDERED:
			if indices.is_empty():
				return []
			var min_index = _ordered_pool.size()
			for index in indices:
				if index < 0 or index >= _ordered_pool.size() or _ordered_pool[index] == null:
					continue
				min_index = min(min_index, index)
				removed.append(_ordered_pool[index])
				_card_id_to_index.erase(_ordered_pool[index].id)
				_ordered_pool[index] = null
			if min_index >= _ordered_pool.size():
				return removed
			var write_index = min_index
			for read_index in range(min_index, _ordered_pool.size()):
				if _ordered_pool[read_index] != null:
					if write_index != read_index:
						_ordered_pool[write_index] = _ordered_pool[read_index]
						_card_id_to_index[_ordered_pool[read_index].id] = write_index
					write_index += 1
			_ordered_pool.resize(write_index)
		AreaMode.UNORDERED:
			var keys = _unordered_pool.keys()
			var ids_to_remove = []
			for idx in indices:
				if idx >= 0 and idx < keys.size():
					ids_to_remove.append(keys[idx])
			removed = remove_cards_by_ids(ids_to_remove)
	return removed
func remove_top_cards(count: int) -> Array[Card]:
	var removed: Array[Card] = []
	count = min(count, card_count())
	match mode:
		AreaMode.ORDERED:
			var start_index = max(0, _ordered_pool.size() - count)
			removed = _ordered_pool.slice(start_index, _ordered_pool.size())
			_ordered_pool.resize(_ordered_pool.size() - count)
			for card in removed:
				_card_id_to_index.erase(card.id)
		AreaMode.UNORDERED:
			var keys = _unordered_pool.keys()
			var start_index = max(0, keys.size() - count)
			var ids = PackedInt32Array()
			for i in range(start_index, keys.size()):
				ids.append(keys[i])
			removed = remove_cards_by_ids(ids)
	return removed
func card_count() -> int:
	match mode:
		AreaMode.ORDERED:
			return _ordered_pool.size()
		AreaMode.UNORDERED:
			return _unordered_pool.size()
	return 0
func get_card_ids() -> Array[int]:
	var ids = []
	match mode:
		AreaMode.ORDERED:
			for card in _ordered_pool:
				ids.append(card.id)
		AreaMode.UNORDERED:
			for card_id in _unordered_pool:
				ids.append(card_id)
	return ids
func get_card_by_id(card_id: int) -> Card:
	match mode:
		AreaMode.ORDERED:
			if _card_id_to_index.has(card_id):
				return _ordered_pool[_card_id_to_index[card_id]]
		AreaMode.UNORDERED:
			return _unordered_pool.get(card_id, null)
	return null
func get_all_cards() -> Array[Card]:
	match mode:
		AreaMode.ORDERED:
			return _ordered_pool.duplicate()
		AreaMode.UNORDERED:
			return  _unordered_pool.values()
	return []
func send_cards_add(new_cardpool: Array[Card]) -> void:
	var trans_cardpool: Array[CardPack]
	trans_cardpool.append_array(new_cardpool.map(func(card): return card.get_pack()))
	RenderRequest.CardAdd.new(area_name, trans_cardpool).send_to_player(player.peer_id)
