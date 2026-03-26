extends RefCounted
class_name Area

var player: Player
var area_name: StringName
var is_private_visible:bool = false
signal area_request_command(command: BehaviorCommand)
signal area_request_command_with_callback(command: BehaviorCommand, callback: Callable)
signal area_card_added(new_cardpool: Card,area:Area)
signal area_card_removed(removed_cards: Card,area:Area)
signal after_cards_removed()

func _init(_player: Player = Player.NULL_PLAYER) -> void:
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
func get_card_ids() -> PackedInt32Array:
	assert(false, "子类必须实现 get_card_ids 方法")
	return []

## 发送物品包到指定对等体（支持自定义事件类型、来源玩家和名称）
func send_items(
	new_items: Array[ItemPack],
	peer_id = MultiplayerPeer.TARGET_PEER_BROADCAST,
	event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.DRAW,
	source_player_id: int = player.player_id,
	custom_event_name: StringName = &""
) -> void:
	RenderRequest.ItemSet.new(
		area_name,
		event_type,
		new_items,
		player.player_id, # area_player_id（区域拥有者）
		source_player_id,   # 事件来源玩家ID
		custom_event_name
	).send_to_player(peer_id)

## 发送卡牌包（如果区域私有，则只发送给所属玩家）
func send_cards(
	new_cardpool: Array[Card],
	event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.DRAW,
	source_player_id:int = player.player_id,
	custom_event_name: StringName = &""
) -> void:
	var card_packs: Array[ItemPack] = []
	card_packs.resize(new_cardpool.size())
	var i: int = 0
	for card in new_cardpool:
		card_packs.set(i, card.get_pack())
		i += 1
	if !is_private_visible:
		send_items(card_packs, MultiplayerPeer.TARGET_PEER_BROADCAST, event_type, source_player_id, custom_event_name)
		return
	if player.peer_id < 0:
		return
	send_items(card_packs, player.peer_id, event_type, source_player_id, custom_event_name)

func shuffle_card_pool() -> void:
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

## 请求命令入栈（无回调）
func request_command(command: BehaviorCommand) -> void:
	area_request_command.emit(command)

## 请求命令入栈（带回调）
func request_command_with_callback(command: BehaviorCommand, callback: Callable) -> void:
	area_request_command_with_callback.emit(command, callback)

func get_player()->Player:
	return player
