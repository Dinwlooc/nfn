## 箭头评估器：负责从区域获取选中卡片，更新箭头位置与方向。
extends RefCounted

const ArrowNode = preload("arrow_node.gd")

var _hand_arrow: ArrowNode
var _player_arrow: ArrowNode
var _render_context: RenderContext

var _cached_hand_target: Vector2 = Vector2.INF
var _cached_hand_dir: Vector2 = Vector2.DOWN
var _cached_player_target: Vector2 = Vector2.INF
var _cached_player_dir: Vector2 = Vector2.UP

var target_player: RenderItem = null
var target_item: RenderItem = null

func init(hand_arrow: ArrowNode, player_arrow: ArrowNode, context: RenderContext) -> void:
	_hand_arrow = hand_arrow
	_player_arrow = player_arrow
	_render_context = context

## 评估手牌箭头，返回是否发生了变化
func apply_hand_arrow(hand_selected: Array[RenderItem]) -> bool:
	if hand_selected.size() > 0:
		return _point_hand_arrow_to(hand_selected[-1])
	else:
		_hide_hand_arrow()
		return false

## 评估玩家箭头，返回是否发生了变化（原方法已返回 bool）
func apply_player_arrow(player_selected: Array[RenderItem], players_area: RenderArea) -> bool:
	if player_selected.size() == 0:
		_hide_player_arrow()
		return false
	var player: RenderItem = player_selected[-1]
	var target_item: RenderItem = _resolve_target(player)
	target_player = player
	target_item = target_item
	if not target_item:
		_hide_player_arrow()
		return false
	var is_local: bool = false
	if players_area is RenderAreaPlayers:
		is_local = (player == (players_area as RenderAreaPlayers).local_player)
	var target_pos: Vector2
	var direction: Vector2
	if target_item == player:
		if is_local:
			target_pos = ArrowNode.get_card_top_center_global(player)
			direction = Vector2.DOWN
		else:
			target_pos = ArrowNode.get_card_bottom_center_global(player)
			direction = Vector2.UP
	else:
		target_pos = ArrowNode.get_card_bottom_center_global(target_item)
		direction = Vector2.UP
	if _cached_player_target == target_pos and _cached_player_dir == direction:
		return false
	_player_arrow.point_to_target(target_pos, direction)
	_cached_player_target = target_pos
	_cached_player_dir = direction
	return true

func _point_hand_arrow_to(card: RenderItem) -> bool:
	var target_pos: Vector2 = ArrowNode.get_card_top_center_global(card)
	var dir: Vector2 = Vector2.DOWN
	if _cached_hand_target == target_pos and _cached_hand_dir == dir and _hand_arrow.state != ArrowNode.State.HIDDEN:
		return false
	_hand_arrow.point_to_target(target_pos, dir)
	_cached_hand_target = target_pos
	_cached_hand_dir = dir
	return true

func _hide_hand_arrow() -> void:
	_hand_arrow.hide_arrow()
	_cached_hand_target = Vector2.INF

func _hide_player_arrow() -> void:
	_player_arrow.hide_arrow()
	_cached_player_target = Vector2.INF
	_cached_player_dir = Vector2.UP
	target_player = null
	target_item = null

func _resolve_target(player: RenderItem) -> RenderItem:
	if not _render_context:
		return player
	var pid: int = 0
	if player.data:
		pid = player.data.get_id()
	if pid <= 0:
		return player
	var defence_area: RenderArea = _render_context.get_render_area(RenderArea.DefaultArea.DEFENCE, pid)
	if defence_area and not defence_area.items_pool.is_empty():
		var last_item: RenderItem = defence_area.items_pool[-1]
		if last_item:
			return last_item
	return player

func clear_cache() -> void:
	_cached_hand_target = Vector2.INF
	_cached_player_target = Vector2.INF
