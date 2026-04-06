## 渲染请求发送规则工具类
class_name TransRule
extends RefCounted

## 发送数量变化请求（仅 ItemCountSet）
static func send_count_change(
	source_area: Area,
	target_area: Area,
	new_total_count: int,
	event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.UPDATE,
	custom_event_name: StringName = &""
) -> void:
	var source_player_id: int = source_area.player.player_id if source_area else RenderRequest.PUBLIC_AREA_PLAYER_ID
	var request = RenderRequest.ItemCountSet.new(
		target_area.area_name,
		new_total_count,
		event_type,
		target_area.player.player_id,
		source_area.area_name if source_area else target_area.area_name,
		source_player_id
	)
	if custom_event_name != &"":
		request.set_custom_event_name(custom_event_name)
	# 数量变化：广播给所有玩家
	request.send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)

## 发送物品包（实体变化）
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

## 发送卡牌包（自动转换 Card -> ItemPack）
static func send_cards(
	source_area: Area,
	target_area: Area,
	new_cards: Array[Card],
	event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.DRAW,
	custom_event_name: StringName = &""
) -> void:
	# 判断是否从非公共可见变为公共可见
	var use_full_pack: bool = false
	if target_area.visibility == Area.Visibility.PUBLIC:
		if source_area == null or source_area.visibility != Area.Visibility.PUBLIC:
			use_full_pack = true
	var item_packs: Array[ItemPack] = []
	item_packs.resize(new_cards.size())
	var i: int = 0
	for card in new_cards:
		item_packs[i] = card.get_full_pack() if use_full_pack else card.get_pack()
		i += 1
	send_items(source_area, target_area, item_packs, event_type, custom_event_name)

## 发送玩家增量更新（供 PlayersManager 调用）
static func send_player_delta_updates(
	delta_packs: Array[ItemPack],
	event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.UPDATE,
	source_player_id: int = RenderRequest.PUBLIC_AREA_PLAYER_ID,
	custom_event_name: StringName = &""
) -> void:
	if delta_packs.is_empty():
		return
	var request = RenderRequest.ItemSet.new(
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

## 分发实体变化请求：根据可见性组合，使用广播/负对等体/单播
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
	# 获取源和目标可见性（若源区域为null，视为PUBLIC）
	var src_vis: Area.Visibility = source_area.visibility if source_area else Area.Visibility.PUBLIC
	var tgt_vis: Area.Visibility = target_area.visibility

	# 构造请求对象的辅助函数
	var make_item_set = func() -> RenderRequest.ItemSet:
		var req = RenderRequest.ItemSet.new(
			target_area_name, event_type, new_items,
			target_area_player_id, source_area_name, source_area_player_id
		)
		if custom_event_name != &"":
			req.set_custom_event_name(custom_event_name)
		return req

	var make_item_count_set = func() -> RenderRequest.ItemCountSet:
		var req = RenderRequest.ItemCountSet.new(
			target_area_name, new_items.size(), event_type,
			target_area_player_id, source_area_name, source_area_player_id
		)
		if custom_event_name != &"":
			req.set_custom_event_name(custom_event_name)
		return req

	# 根据组合处理
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
			push_error("TransRule: PRIVATE->PRIVATE not implemented, please handle manually")
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
			push_error("TransRule: unknown visibility combination")
