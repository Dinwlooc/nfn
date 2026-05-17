extends RefCounted
class_name RuleTrans

static func send_count_change(
	source_area: Area,
	target_area: Area,
	new_total_count: int,
	event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.UPDATE,
	custom_params: Dictionary[StringName,Variant] = {}
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
	request.set_custom_params(custom_params)
	request.send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)

static func send_items(
	source_area: Area,
	target_area: Area,
	new_items: Array[ItemPack],
	event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.DRAW,
	custom_params: Dictionary[StringName,Variant] = {}
) -> void:
	_distribute_item_request(
		source_area, target_area, new_items,
		target_area.area_name, event_type,
		target_area.player.player_id,
		custom_params,
		source_area.area_name if source_area else target_area.area_name,
		source_area.player.player_id if source_area else target_area.player.player_id
	)

static func send_cards(
	source_area: Area,
	target_area: Area,
	new_cards: Array[Card],
	event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.DRAW,
	custom_params: Dictionary[StringName,Variant] = {}
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
	send_items(source_area, target_area, item_packs, event_type, custom_params)

static func send_player_delta_updates(
	players: Array[Player],
	event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.UPDATE,
	source_player_id: int = RenderRequest.PUBLIC_AREA_PLAYER_ID,
	custom_params: Dictionary[StringName,Variant] = {}
) -> void:
	if players.is_empty():
		return
	var delta_packs: Array[ItemPack] = []
	for player: Player in players:
		var pack: PlayerPack = player.get_pack()
		if pack:
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
	request.set_custom_params(custom_params)
	request.send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)

static func send_player_delta_packs(
	delta_packs: Array[ItemPack],
	event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.UPDATE,
	source_player_id: int = RenderRequest.PUBLIC_AREA_PLAYER_ID,
	custom_params: Dictionary[StringName,Variant] = {}
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
	request.set_custom_params(custom_params)
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

static func _distribute_item_request(
	source_area: Area,
	target_area: Area,
	new_items: Array[ItemPack],
	target_area_name: StringName,
	event_type: RenderRequest.ItemSet.EventType,
	target_area_player_id: int,
	custom_params: Dictionary[StringName,Variant],
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
		req.set_custom_params(custom_params)
		return req
	var make_item_count_set: Callable = func() -> RenderRequest.ItemCountSet:
		var req: RenderRequest.ItemCountSet = RenderRequest.ItemCountSet.new(
			target_area_name, new_items.size(), event_type,
			target_area_player_id, source_area_name, source_area_player_id
		)
		req.set_custom_params(custom_params)
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
	custom_params: Dictionary[StringName,Variant] = {}
) -> void:
	if buff_modifiers.owner_type == &"card":
		var card: Card = game_state.cardsmanager.get_card_by_id(buff_modifiers.owner_id)
		if not card:
			push_error("RuleTrans.send_buff_modifiers_update: 未找到卡牌 id ", buff_modifiers.owner_id)
			return
		var target_area: Area = game_state.area_registry.get_area(card.area_player_id, card.area_name)
		if not target_area:
			push_error("RuleTrans.send_buff_modifiers_update: 无法定位卡牌所在区域")
			return
		send_cards(null, target_area, [card], event_type, custom_params)
	elif buff_modifiers.owner_type == &"player":
		var player: Player = game_state.player_manager.get_player_by_id(buff_modifiers.owner_id)
		if not player:
			push_error("RuleTrans.send_buff_modifiers_update: 未找到玩家 id ", buff_modifiers.owner_id)
			return
		send_player_delta_updates([player], event_type, RenderRequest.PUBLIC_AREA_PLAYER_ID, custom_params)
	else:
		push_error("RuleTrans.send_buff_modifiers_update: 未知的所有者类型 ", buff_modifiers.owner_type)

## 发送阶段切换通知（使用当前活跃阶段名）
static func send_stage_switch_notify(game_state: GameState, custom_params: Dictionary[StringName,Variant] = {}) -> void:
	var cur_stage: Stage = game_state.stage_manager.current_stage
	if not cur_stage:
		return
	var player_id: int = game_state.stage_manager.current_player_id
	var stage_name: StringName = cur_stage.stage_name
	var temp_owner_id: int = cur_stage.temporary_stage_player_id
	var request: RenderRequest.StageNotifyRequest = RenderRequest.StageNotifyRequest.new(player_id, stage_name, temp_owner_id, custom_params)
	request.send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)
