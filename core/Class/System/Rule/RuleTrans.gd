## 渲染请求发送规则工具类
class_name TransRule
extends RefCounted

## 发送数量变化请求（仅 ItemCountSet）
static func send_count_change(
	source_area: Area,
	target_area: Area,
	new_total_count: int,
	event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.UPDATE,
	source_player_id: int = -1,
	custom_event_name: StringName = &""
) -> void:
	if source_player_id == -1 and source_area:
		source_player_id = source_area.player.player_id
	var request = RenderRequest.ItemCountSet.new(
		target_area.area_name,
		new_total_count,
		event_type,
		target_area.player.player_id,
		source_player_id,
		custom_event_name
	)
	request.source_area_name = source_area.area_name if source_area else &""
	request.source_area_player_id = source_area.player.player_id if source_area else RenderRequest.PUBLIC_AREA_PLAYER_ID
	# 数量变化：广播给所有玩家（因为 INVISIBLE 区域数量对所有可见，其他情况不会单独调用）
	request.send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)

## 发送物品包（实体变化）
static func send_items(
	source_area: Area,
	target_area: Area,
	new_items: Array[ItemPack],
	event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.DRAW,
	source_player_id: int = -1,
	custom_event_name: StringName = &""
) -> void:
	if source_player_id == -1 and source_area:
		source_player_id = source_area.player.player_id
	_distribute_item_request(
		source_area, target_area, new_items,
		target_area.area_name, event_type,
		target_area.player.player_id, source_player_id, custom_event_name,
		source_area.area_name if source_area else &"",
		source_area.player.player_id if source_area else RenderRequest.PUBLIC_AREA_PLAYER_ID
	)

## 发送卡牌包（自动转换 Card -> ItemPack）
static func send_cards(
	source_area: Area,
	target_area: Area,
	new_cards: Array[Card],
	event_type: RenderRequest.ItemSet.EventType = RenderRequest.ItemSet.EventType.DRAW,
	source_player_id: int = -1,
	custom_event_name: StringName = &""
) -> void:
	if source_player_id == -1 and source_area:
		source_player_id = source_area.player.player_id
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
	send_items(source_area, target_area, item_packs, event_type, source_player_id, custom_event_name)

## 分发实体变化请求：根据可见性组合，使用广播/负对等体/单播
static func _distribute_item_request(
	source_area: Area,
	target_area: Area,
	new_items: Array[ItemPack],
	target_area_name: StringName,
	event_type: RenderRequest.ItemSet.EventType,
	target_area_player_id: int,
	source_player_id: int,
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
			target_area_player_id, source_player_id, custom_event_name
		)
		req.source_area_name = source_area_name
		req.source_area_player_id = source_area_player_id
		return req
	var make_item_count_set = func() -> RenderRequest.ItemCountSet:
		var req = RenderRequest.ItemCountSet.new(
			target_area_name, new_items.size(), event_type,
			target_area_player_id, source_player_id, custom_event_name
		)
		req.source_area_name = source_area_name
		req.source_area_player_id = source_area_player_id
		return req
	# 根据组合处理
	match [src_vis, tgt_vis]:
		[Area.Visibility.PUBLIC, Area.Visibility.PUBLIC]:
			# S = 全体 -> 广播 ItemSet
			make_item_set.call().send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)
		[Area.Visibility.PUBLIC, Area.Visibility.PRIVATE]:
			# S = 全体 -> 广播 ItemSet
			make_item_set.call().send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)
		[Area.Visibility.PUBLIC, Area.Visibility.INVISIBLE]:
			# S = 全体 -> 广播 ItemSet
			make_item_set.call().send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)
		[Area.Visibility.PRIVATE, Area.Visibility.PUBLIC]:
			# S = 全体 -> 广播 ItemSet
			make_item_set.call().send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)
		[Area.Visibility.PRIVATE, Area.Visibility.PRIVATE]:
			# 留空处理（需要更复杂的逻辑，暂不实现）
			push_error("TransRule: PRIVATE->PRIVATE not implemented, please handle manually")
			return
		[Area.Visibility.PRIVATE, Area.Visibility.INVISIBLE]:
			# S = {源所有者} -> 单播 ItemSet 给源所有者，其余人 ItemCountSet（负对等体排除源所有者）
			var owner_peer: int = source_area.player.peer_id
			# 发送 ItemSet 给源所有者
			make_item_set.call().send_to_player(owner_peer)
			# 发送 ItemCountSet 给除源所有者外的所有人
			make_item_count_set.call().send_to_player(-owner_peer)
		[Area.Visibility.INVISIBLE, Area.Visibility.PUBLIC]:
			# S = 全体 -> 广播 ItemSet
			make_item_set.call().send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)
		[Area.Visibility.INVISIBLE, Area.Visibility.PRIVATE]:
			# S = {目标所有者} -> 单播 ItemSet 给目标所有者，其余人 ItemCountSet（负对等体排除目标所有者）
			var owner_peer: int = target_area.player.peer_id
			make_item_set.call().send_to_player(owner_peer)
			make_item_count_set.call().send_to_player(-owner_peer)
		[Area.Visibility.INVISIBLE, Area.Visibility.INVISIBLE]:
			# S = 空 -> 广播 ItemCountSet
			make_item_count_set.call().send_to_player(MultiplayerPeer.TARGET_PEER_BROADCAST)
		_:
			push_error("TransRule: unknown visibility combination")
