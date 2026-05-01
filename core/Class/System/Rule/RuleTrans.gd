extends RefCounted
class_name RuleTrans

static func send_count_change(
	source_area: Area,
	target_area: Area,
	new_total_count: int,
	event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.UPDATE,
	custom_event_name: StringName = &""
) -> void:
	var source_player_id: int = source_area.player.player_id if source_area else RenderRequest.PUBLIC_AREA_PLAYER_ID
	var request: RenderRequest.ItemCountSet = RenderRequest.ItemCountSet.new(
		target_area.area_name,
		new_total_count,
		event_type,
		target_area.player.player_id,
		source_area.area_name if source_area else target_area.area_name,
		source_player_id
	)
	if custom_event_name != &"":
		request.set_custom_event_name(custom_event_name)
	request.send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)

static func send_items(
	source_area: Area,
	target_area: Area,
	new_items: Array[ItemPack],
	event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.DRAW,
	custom_event_name: StringName = &""
) -> void:
	_distribute_item_request(
		source_area, target_area, new_items,
		target_area.area_name, event_type,
		target_area.player.player_id,
		custom_event_name,
		source_area.area_name if source_area else target_area.area_name,
		source_area.player.player_id if source_area else target_area.player.player_id
	)

static func send_cards(
	source_area: Area,
	target_area: Area,
	new_cards: Array[Card],
	event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.DRAW,
	custom_event_name: StringName = &""
) -> void:
	var use_full_pack: bool = false
	if target_area.visibility == Area.Visibility.PUBLIC:
		if source_area == null or source_area.visibility != Area.Visibility.PUBLIC:
			use_full_pack = true
	var item_packs: Array[ItemPack] = []
	item_packs.resize(new_cards.size())
	var i: int = 0
	for card: Card in new_cards:
		item_packs[i] = card.get_full_pack() if use_full_pack else card.get_pack()
		i += 1
	send_items(source_area, target_area, item_packs, event_type, custom_event_name)

static func send_player_delta_updates(
	players: Array[Player],
	event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.UPDATE,
	source_player_id: int = RenderRequest.PUBLIC_AREA_PLAYER_ID,
	custom_event_name: StringName = &""
) -> void:
	if players.is_empty():
		return
	var delta_packs: Array[ItemPack] = []
	for player: Player in players:
		var pack: PlayerPack = player.get_pack()
		if pack and pack.merge_mask != 0:
			delta_packs.append(pack)
	if delta_packs.is_empty():
		return
	var request: RenderRequest.ItemSet = RenderRequest.ItemSet.new(
		GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.PLAYERS],
		event_type,
		delta_packs,
		RenderRequest.PUBLIC_AREA_PLAYER_ID,
		GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.PLAYERS],
		source_player_id
	)
	if custom_event_name != &"":
		request.set_custom_event_name(custom_event_name)
	request.send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)

static func send_player_delta_packs(
	delta_packs: Array[ItemPack],
	event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.UPDATE,
	source_player_id: int = RenderRequest.PUBLIC_AREA_PLAYER_ID,
	custom_event_name: StringName = &""
) -> void:
	if delta_packs.is_empty():
		return
	var request: RenderRequest.ItemSet = RenderRequest.ItemSet.new(
		GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.PLAYERS],
		event_type,
		delta_packs,
		RenderRequest.PUBLIC_AREA_PLAYER_ID,
		GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.PLAYERS],
		source_player_id
	)
	if custom_event_name != &"":
		request.set_custom_event_name(custom_event_name)
	request.send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)

static func send_players_full_updates(players: Array[Player], peer_id: int) -> void:
	var full_packs: Array[ItemPack] = []
	for player: Player in players:
		full_packs.append(player.get_full_pack())
	if full_packs.is_empty():
		return
	var request: RenderRequest.ItemSet = RenderRequest.ItemSet.new(
		GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.PLAYERS],
		RenderRequest.ItemSet.EventType.UPDATE,
		full_packs,
		RenderRequest.PUBLIC_AREA_PLAYER_ID,
		GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.PLAYERS],
		RenderRequest.PUBLIC_AREA_PLAYER_ID
	)
	GlobalTransport.send_render_request(peer_id, request)

static func send_all_players_full_updates_from_manager(manager: PlayersManager, peer_id: int) -> void:
	send_players_full_updates(manager.players, peer_id)

## 发送 Buff 修饰器更新（根据所有者类型和 ID 自动选择卡牌或玩家更新）
static func send_buff_update(buff_modifiers: BuffModifiers, event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.UPDATE, custom_event_name: StringName = &"") -> void:
	if buff_modifiers.owner_type == &"card":
		var card: Card = _get_card_by_id(buff_modifiers.owner_id)
		if not card:
			push_error("RuleTrans.send_buff_update: Card not found with id ", buff_modifiers.owner_id)
			return
		var target_area: Area = _get_card_area(card)
		if not target_area:
			push_error("RuleTrans.send_buff_update: Cannot determine area for card ", card.id)
			return
		send_cards(null, target_area, [card], event_type, custom_event_name)
	elif buff_modifiers.owner_type == &"player":
		var player: Player = _get_player_by_id(buff_modifiers.owner_id)
		if not player:
			push_error("RuleTrans.send_buff_update: Player not found with id ", buff_modifiers.owner_id)
			return
		send_player_delta_updates([player], event_type, RenderRequest.PUBLIC_AREA_PLAYER_ID, custom_event_name)
	else:
		push_error("RuleTrans.send_buff_update: Unknown owner_type ", buff_modifiers.owner_type)

## 根据卡牌获取其所在区域（需要实现全局区域管理）
static func _get_card_area(card: Card) -> Area:
	# TODO: 通过全局 GameState 或 AreaRegistry 根据 card.area_name 和 card.area_player_id 获取 Area 实例
	# 示例访问方式（假设存在全局单例 GameState）：
	# return GameState.area_registry.get_area(card.area_name, card.area_player_id)
	return null

## 根据卡牌 ID 获取卡牌实例（需要全局 CardsManager）
static func _get_card_by_id(card_id: int) -> Card:
	# TODO: 通过全局 GameState 或 CardsManager 获取
	# return GameState.cardsmanager.get_card_by_id(card_id)
	return null

## 根据玩家 ID 获取玩家实例（需要全局 PlayersManager）
static func _get_player_by_id(player_id: int) -> Player:
	# TODO: 通过全局 GameState 或 PlayersManager 获取
	# return GameState.player_manager.get_player_by_id(player_id)
	return null

static func _distribute_item_request(
	source_area: Area,
	target_area: Area,
	new_items: Array[ItemPack],
	target_area_name: StringName,
	event_type: RenderRequest.ItemSet.EventType,
	target_area_player_id: int,
	custom_event_name: StringName,
	source_area_name: StringName,
	source_area_player_id: int
) -> void:
	var src_vis: Area.Visibility = source_area.visibility if source_area else Area.Visibility.PUBLIC
	var tgt_vis: Area.Visibility = target_area.visibility

	var make_item_set: Callable = func() -> RenderRequest.ItemSet:
		var req: RenderRequest.ItemSet = RenderRequest.ItemSet.new(
			target_area_name, event_type, new_items,
			target_area_player_id, source_area_name, source_area_player_id
		)
		if custom_event_name != &"":
			req.set_custom_event_name(custom_event_name)
		return req

	var make_item_count_set: Callable = func() -> RenderRequest.ItemCountSet:
		var req: RenderRequest.ItemCountSet = RenderRequest.ItemCountSet.new(
			target_area_name, new_items.size(), event_type,
			target_area_player_id, source_area_name, source_area_player_id
		)
		if custom_event_name != &"":
			req.set_custom_event_name(custom_event_name)
		return req

	match [src_vis, tgt_vis]:
		[Area.Visibility.PUBLIC, Area.Visibility.PUBLIC]:
			make_item_set.call().send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)
		[Area.Visibility.PUBLIC, Area.Visibility.PRIVATE]:
			make_item_set.call().send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)
		[Area.Visibility.PUBLIC, Area.Visibility.INVISIBLE]:
			make_item_set.call().send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)
		[Area.Visibility.PRIVATE, Area.Visibility.PUBLIC]:
			make_item_set.call().send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)
		[Area.Visibility.PRIVATE, Area.Visibility.PRIVATE]:
			push_error("RuleTrans: PRIVATE->PRIVATE not implemented, please handle manually")
			return
		[Area.Visibility.PRIVATE, Area.Visibility.INVISIBLE]:
			var owner_peer: int = source_area.player.peer_id
			make_item_set.call().send_to_player(owner_peer)
			make_item_count_set.call().send_to_player(-owner_peer)
		[Area.Visibility.INVISIBLE, Area.Visibility.PUBLIC]:
			make_item_set.call().send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)
		[Area.Visibility.INVISIBLE, Area.Visibility.PRIVATE]:
			var owner_peer: int = target_area.player.peer_id
			make_item_set.call().send_to_player(owner_peer)
			make_item_count_set.call().send_to_player(-owner_peer)
		[Area.Visibility.INVISIBLE, Area.Visibility.INVISIBLE]:
			make_item_count_set.call().send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)
		_:
			push_error("RuleTrans: unknown visibility combination")

## 发送 BuffModifiers 的更新（根据所有者类型自动选择卡牌或玩家）
static func send_buff_modifiers_update(
	game_state: GameState,
	buff_modifiers: BuffModifiers,
	event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.UPDATE,
	custom_event_name: StringName = &""
) -> void:
	if buff_modifiers.owner_type == &"card":
		var card: Card = game_state.cardsmanager.get_card_by_id(buff_modifiers.owner_id)
		if not card:
			push_error("RuleTrans.send_buff_modifiers_update: 未找到卡牌 id ", buff_modifiers.owner_id)
			return
		var target_area: Area = game_state.area_registry.get_area(card.area_name, card.area_player_id)
		if not target_area:
			push_error("RuleTrans.send_buff_modifiers_update: 无法定位卡牌所在区域")
			return
		send_cards(null, target_area, [card], event_type, custom_event_name)
	elif buff_modifiers.owner_type == &"player":
		var player: Player = game_state.player_manager.get_player_by_id(buff_modifiers.owner_id)
		if not player:
			push_error("RuleTrans.send_buff_modifiers_update: 未找到玩家 id ", buff_modifiers.owner_id)
			return
		send_player_delta_updates([player], event_type, RenderRequest.PUBLIC_AREA_PLAYER_ID, custom_event_name)
	else:
		push_error("RuleTrans.send_buff_modifiers_update: 未知的所有者类型 ", buff_modifiers.owner_type)
