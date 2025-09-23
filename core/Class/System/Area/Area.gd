extends RefCounted
class_name Area

var card_pool:Array[Card] = []
#区域卡池。存放卡牌（Card类）。
var player:Player
var area_name:StringName

signal area_cards_add(new_cardpool)

func _init(_player:Player = null) -> void:
	player = _player
	area_cards_add.connect(send_cards_add)
	_init_expand()

func _init_expand()->void:
	pass

func cards_add(new_cardpool:Array[Card])->void:
	card_pool.append_array(new_cardpool)
	area_cards_add.emit(new_cardpool)
	pass

func send_cards_add(new_cardpool:Array[Card])->void:
	var trans_cardpool:Array[CardPack]
	trans_cardpool.append_array(new_cardpool.map(func(card)->CardPack:return card.get_pack()))
	RenderRequest.CardAdd.new(area_name,trans_cardpool).send_to_player(player.peer_id)

func remove_top_cards(count: int) -> Array[Card]:
	var start_index = max(0, card_pool.size() - count)
	var removed = card_pool.slice(start_index, card_pool.size())
	card_pool.resize(card_pool.size() - count)
	return removed

func remove_cards_at_indices(indices: PackedInt32Array) -> Array[Card]:
	indices.sort()
	var removed = []
	for i in range(indices.size() - 1, -1, -1):
		var idx = indices[i]
		if idx < card_pool.size():
			removed.insert(0, card_pool[idx])
			card_pool.remove_at(idx)
	return removed
