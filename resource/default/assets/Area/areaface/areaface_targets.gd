## 目标选择面板：按玩家区选牌状态自动移动/缩放角色卡并处理快捷选择。
extends AreaFace

## 面板原始位置
var original_position: Vector2
## 面板原始尺寸
var original_size: Vector2
## 卡牌排列目标区域的中心位置
var area_target_position: Vector2
## 卡牌排列目标区域的尺寸
var area_target_size: Vector2
## 卡牌移动补间时长（秒）
const TWEEN_TIME = 0.35

## 当前监听的手牌区
var _hand_area: RenderAreaHand = null
## 手牌选中回调（缓存以便成对断连）
var _hand_selected_callback: Callable

## 就绪：登记玩家区并记录原始几何
func _ready() -> void:
	request_area(RenderArea.DefaultArea.PLAYERS)
	original_position = global_position
	original_size = size
	area_target_position = original_position
	area_target_size = original_size
	_hand_selected_callback = _on_hand_selected

## 接入区域：额外订阅手牌区的出现/替换
## @override
func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	# 主区域为玩家区，额外监听手牌区
	if target_area is RenderAreaPlayers and render_context:
		render_context.connect_renderarea(
			RenderArea.DefaultArea.HAND,
			_on_hand_area_connected,
			RenderContext.PUBLIC_PLAYER_ID
		)

## 断开区域连接并清理手牌选中回调
## @override
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

## 手牌区替换回调：把选中监听切换到新手牌区
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

## 手牌选中：把选择转成对玩家目标的快捷选择
func _on_hand_selected(item: RenderItem) -> void:
	if area and area is RenderAreaPlayers:
		quickly_select(area as RenderAreaPlayers, item)

## 渲染更新：按目标区域尺寸重算卡牌排列坐标
## @override
func render_update(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	if not area or area.items_pool.is_empty():
		return
	var item_size: Vector2 = area.items_pool[0].get_item_size()
	var virtual_pos: Vector2 = area_target_position - item_size / 2.0
	target_position = UIAnimationUtils.generate_coordinates(virtual_pos, area_target_size, area.items_pool.size() - 1)
	tween_update()

## 补间更新：触发卡牌移动
## @override
func tween_update(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	card_move()

## 进入区域：额外广播一次入区渲染请求
## @override
func _into_area() -> void:
	super._into_area()
	if area:
		area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.INTO_AREA))

## 离开区域：额外广播一次出区渲染请求
## @override
func _outto_area() -> void:
	super._outto_area()
	if area:
		area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.OUTTO_AREA))

## 把区域内非本地玩家的卡牌移动到计算出的排列位置
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

## 快捷选择：按当前所选卡牌类型自动选择/取消目标玩家
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
