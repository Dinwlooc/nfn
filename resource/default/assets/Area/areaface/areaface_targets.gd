## 目标选择面板：按玩家区选牌状态把角色卡排布到目标区域，并把所选手牌转成快捷选择。
extends AreaFace

#==vars==
## 面板原始位置
var original_position: Vector2
## 面板原始尺寸
var original_size: Vector2
## 卡牌排列目标区域的中心位置
var area_target_position: Vector2
## 卡牌排列目标区域的尺寸
var area_target_size: Vector2
## 角色卡排布补间槽位
var layout_tween: Tween = null
## 当前监听的手牌区
var _hand_area: RenderAreaHand = null
## 手牌选中回调（缓存以便成对断连）
var _hand_selected_callback: Callable

#==consts==
## 卡牌移动补间时长（秒）
const TWEEN_TIME: float = 0.35

#==lifecycle==
## 就绪：登记玩家区并记录原始几何。
## @override
func _ready() -> void:
	request_area(RenderArea.DefaultArea.PLAYERS)
	original_position = global_position
	original_size = size
	area_target_position = original_position
	area_target_size = original_size
	_hand_selected_callback = _on_hand_selected

#==hooks==
## 渲染更新：按目标区域尺寸重算卡牌排列坐标。
## @override
func render_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	if not area or area.items_pool.is_empty():
		return
	var item_size: Vector2 = area.items_pool[0].get_item_size()
	var virtual_pos: Vector2 = area_target_position - item_size / 2.0
	target_position = UIAnimationUtils.generate_coordinates(virtual_pos, area_target_size, area.items_pool.size() - 1)
	tween_update(render_event)
## 补间更新：提交角色卡排布。
## @override
func tween_update(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	card_move()
## 进入区域：向区域广播一次入区渲染请求。
## @override
func on_into_area() -> void:
	if area:
		area.tween_requested.emit(RenderEvent.new(RenderEvent.DefaultType.INTO_AREA))
## 离开区域：向区域广播一次出区渲染请求。
## @override
func on_outto_area() -> void:
	if area:
		area.tween_requested.emit(RenderEvent.new(RenderEvent.DefaultType.OUTTO_AREA))
## 区域接入：额外订阅手牌区的出现/替换。
## @override @signal_listener
func _connect_to_area(target_area: RenderArea) -> void:
	super._connect_to_area(target_area)
	# 主区域为玩家区，额外监听手牌区
	if target_area is RenderAreaPlayers and render_context:
		render_context.connect_renderarea(
			RenderArea.DefaultArea.HAND,
			_on_hand_area_connected,
			RenderContext.PUBLIC_PLAYER_ID
		)
## 区域断开：取消手牌区监听与选中回调后交给父类清理。
## @override @signal_listener
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
#==tween==
## 角色卡排布：把非本地玩家卡并行补间到计算位置；无可动卡牌时由卫语句拦住。
## @atomic
func card_move(_render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	if not area or area.items_pool.is_empty() or target_position.is_empty():
		return
	var cards: Array[RenderItem] = []
	var targets: PackedVector2Array = PackedVector2Array()
	var skipped_local_players_count: int = 0
	for i in range(area.items_pool.size()):
		var player: RenderItem = area.items_pool[i]
		if player.data.peer_id == multiplayer.get_unique_id():
			skipped_local_players_count += 1
			continue
		cards.append(player)
		targets.append(target_position[i - skipped_local_players_count])
	if cards.is_empty():
		return
	var master_tween: Tween = create_tween()
	do_target_layout(master_tween, cards, targets)
	layout_tween = UIAnimationUtils.replace_tween(layout_tween, master_tween)
	if not layout_tween.has_tweeners():
		layout_tween.kill()
## 排布装配：已在该落点的卡不追加补间。
## @atomic
static func do_target_layout(tween: Tween, cards: Array[RenderItem], targets: PackedVector2Array) -> void:
	tween.set_parallel(true)
	for i in cards.size():
		var card: RenderItem = cards[i]
		if card.position == targets[i]:
			continue
		tween.tween_property(card, ^"position", targets[i], TWEEN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


#==internal==
## 手牌区替换：把选中监听切换到新手牌区
## @signal_listener
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
## @signal_listener
func _on_hand_selected(item: RenderItem) -> void:
	if area and area is RenderAreaPlayers:
		quickly_select(area as RenderAreaPlayers, item)
## 快捷选择：按当前所选卡牌类型自动选择/取消目标玩家
## @external
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

#==input==
## 输入事件处理：手牌拖拽经过本区时把悬停转为目标选择，并在本区释放时触发打出。
## @chain_override
func _input(event: InputEvent) -> void:
	super._input(event)
	if not visible:
		return
	if not get_dragged_hand_card():
		return
	if event is InputEventMouseMotion:
		hover_select_target()
		return
	try_play_on_drop(event)

## 取当前拖拽中的手牌；非手牌拖拽时返回 null。
## @nullable_pure
func get_dragged_hand_card() -> RenderItem:
	if not area:
		return null
	var context: RenderContext = area.render_context
	if not context:
		return null
	var card: RenderItem = context.get_dragged_card()
	if not card:
		return null
	if card.area_name != RenderArea.DefaultArea.HAND:
		return null
	return card

## 按鼠标位置取命中的玩家卡；本地玩家与空位返回 null。
## @nullable_pure
func get_player_by_mouse() -> RenderItem:
	if not area is RenderAreaPlayers:
		return null
	var players_area: RenderAreaPlayers = area as RenderAreaPlayers
	var mouse_position: Vector2 = get_global_mouse_position()
	for player: RenderItem in players_area.items_pool:
		if player == players_area.local_player:
			continue
		if Rect2(player.global_position, player.get_item_size()).has_point(mouse_position):
			return player
	return null

## 拖拽悬停选择：命中未选中的玩家卡时转为选中；已选中的不重复处理。
## @external
func hover_select_target() -> void:
	var player: RenderItem = get_player_by_mouse()
	if not player:
		return
	if player.selected:
		return
	var players_area: RenderAreaPlayers = area as RenderAreaPlayers
	players_area.on_select(player)

## 落点打出：鼠标在本区内释放时交给操作管理器，与出牌按钮同一条入口。
## @external
func try_play_on_drop(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		return
	if not Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()):
		return
	if not render_context:
		return
	var op_manager: OperationManager = render_context.get_operation_manager()
	if not op_manager:
		return
	op_manager.upload_play_card()
