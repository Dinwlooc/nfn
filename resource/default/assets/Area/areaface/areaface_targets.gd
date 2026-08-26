extends AreaFace

var original_position: Vector2
var original_size: Vector2
var area_target_position: Vector2
var area_target_size: Vector2
const TWEEN_TIME = 0.35

var _hand_area: RenderAreaHand = null
var _hand_selected_callback: Callable

func _ready() -> void:
	request_area(RenderArea.DefaultArea.PLAYERS)
	original_position = global_position
	original_size = size
	area_target_position = original_position
	area_target_size = original_size
	_hand_selected_callback = _on_hand_selected

func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	# 主区域为玩家区，额外监听手牌区
	if target_area is RenderAreaPlayers and render_context:
		render_context.connect_renderarea(
			RenderArea.DefaultArea.HAND,
			_on_hand_area_connected,
			RenderContext.PUBLIC_PLAYER_ID
		)

func _disconnect_from_area(target_area: RenderArea) -> void:
	if target_area is RenderAreaPlayers and render_context:
		render_context.disconnect_renderarea(
			RenderArea.DefaultArea.HAND,
			_on_hand_area_connected,
			RenderContext.PUBLIC_PLAYER_ID
		)
	if _hand_area:
		if _hand_area.selected.is_connected(_hand_selected_callback):
			_hand_area.selected.disconnect(_hand_selected_callback)
		_hand_area = null
	super._disconnect_from_area(target_area)

func _on_hand_area_connected(new_hand: RenderArea, old_hand: RenderArea) -> void:
	if old_hand and old_hand is RenderAreaHand:
		if old_hand.selected.is_connected(_hand_selected_callback):
			old_hand.selected.disconnect(_hand_selected_callback)
		if _hand_area == old_hand:
			_hand_area = null
	if new_hand and new_hand is RenderAreaHand:
		_hand_area = new_hand as RenderAreaHand
		if not _hand_area.selected.is_connected(_hand_selected_callback):
			_hand_area.selected.connect(_hand_selected_callback)

func _on_hand_selected(item: RenderItem) -> void:
	if area and area is RenderAreaPlayers:
		quickly_select(area as RenderAreaPlayers, item)

func render_update(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	if not area or area.items_pool.is_empty():
		return
	var item_size: Vector2 = area.items_pool[0].get_item_size()
	var virtual_pos: Vector2 = area_target_position - item_size / 2.0
	target_position = UIAnimationUtils.generate_coordinates(virtual_pos, area_target_size, area.items_pool.size() - 1)
	tween_update()

func tween_update(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	card_move()

func _into_area() -> void:
	super._into_area()
	if area:
		area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.INTO_AREA))

func _outto_area() -> void:
	super._outto_area()
	if area:
		area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.OUTTO_AREA))

func card_move() -> void:
	if not area or area.items_pool.is_empty() or target_position.is_empty():
		return
	var skipped_local_players_count: int = 0
	for i in range(area.items_pool.size()):
		var player: RenderItem = area.items_pool[i]
		if player.data.peer_id == multiplayer.get_unique_id():
			skipped_local_players_count += 1
			continue
		var target_pos: Vector2 = target_position[i - skipped_local_players_count]
		if player.position == target_pos:
			continue
		UIAnimationUtils.tween_animations(player, {^"position": target_pos}, TWEEN_TIME)

func quickly_select(players_area: RenderAreaPlayers, item: RenderItem) -> void:
	if not players_area or players_area.items_pool.is_empty():
		return
	var card_type: StringName = item.data.get_card_type()
	var selected: Array[RenderItem] = players_area.get_selected_items()
	var local_player: RenderItem = players_area.local_player
	match card_type:
		GlobalConstants.DefaultCard.ATTACK:
			if selected.is_empty():
				for player in players_area.items_pool:
					if player != local_player:
						players_area.on_select(player)
						break
			elif selected[0] == local_player:
				players_area.on_select(selected[0])
				for player in players_area.items_pool:
					if player != local_player:
						players_area.on_select(player)
						break
		GlobalConstants.DefaultCard.DEFENCE:
			var has_self: bool = false
			for s in selected:
				if s == local_player:
					has_self = true
					continue
				players_area.on_select(s)
			if not has_self:
				players_area.on_select(players_area.local_player)
