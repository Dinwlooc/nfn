extends RefCounted
class_name Area

var player: Player
var area_name: StringName
signal area_cards_add(new_cardpool: Array[Card])
signal area_cards_remove(removed_cards: Array[Card])

func _init(_player: Player = null) -> void:
	player = _player
	_init_expand()

func _init_expand() -> void:
	pass
# 抽象方法，子类必须实现
func cards_add(new_cardpool: Array[Card]) -> void:
	assert(false, "子类必须实现 cards_add 方法")
func remove_cards_by_ids(ids: PackedInt32Array) -> Array[Card]:
	assert(false, "子类必须实现 remove_cards_by_ids 方法")
	return []
func card_count() -> int:
	assert(false, "子类必须实现 card_count 方法")
	return 0
func get_card_by_id(card_id: int) -> Card:
	assert(false, "子类必须实现 get_card_by_id 方法")
	return null
func get_all_cards() -> Array[Card]:
	assert(false, "子类必须实现 get_all_cards 方法")
	return []
func get_card_ids() -> Array[int]:
	assert(false, "子类必须实现 get_card_ids 方法")
	return []
# 公共方法（都有默认实现）
func send_items_add(new_items: Array[CardPack]) -> void:
	if player:
		RenderRequest.ItemAdd.new(area_name, new_items).send_to_player(player.peer_id)
	else:
		RenderRequest.ItemAdd.new(area_name, new_items).send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)

func send_items_remove(uids: PackedInt32Array) -> void:
	if player:
		RenderRequest.ItemRemove.new(area_name, uids).send_to_player(player.peer_id)
	else:
		RenderRequest.ItemRemove.new(area_name, uids).send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)

func send_item_update(item: TransPack) -> void:
	if player:
		RenderRequest.ItemUpdate.new(area_name, item).send_to_player(player.peer_id)
	else:
		RenderRequest.ItemUpdate.new(area_name, item).send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)

func send_cards_add(new_cardpool: Array[Card]) -> void:
	var card_packs: Array[CardPack] = []
	card_packs.resize(new_cardpool.size())
	var i: int = 0
	for card in new_cardpool:
		card_packs.set(i, card.get_pack())
		i += 1
	send_items_add(card_packs)

# 可选方法（有些区域可能不支持）
func shuffle_card_pool() -> void:
	# 默认实现什么也不做，无序区域可以重写
	pass

func remove_cards_at_indices(indices: PackedInt32Array) -> Array[Card]:
	push_error("此区域不支持按索引移除")
	return []

func remove_top_cards(count: int) -> Array[Card]:
	push_error("此区域不支持堆顶移除")
	return []

func get_cards_by_ids(ids: PackedInt32Array) -> Array[Card]:
	var result: Array[Card] = []
	for id in ids:
		var card = get_card_by_id(id)
		if card:
			result.append(card)
	return result

func get_cards_at_indices(indices: PackedInt32Array) -> Array[Card]:
	push_error("此区域不支持按索引获取")
	return []

func get_top_cards(count: int) -> Array[Card]:
	push_error("此区域不支持获取顶部卡牌")
	return []
