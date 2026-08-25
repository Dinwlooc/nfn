## 箭头线构建器：生成主线和敌方线的曲线点集，并启动电光动画。
extends RefCounted

const ArrowNode = preload("arrow_node.gd")
const ArrowLine = preload("arrow_line.gd")

## 曲线细分精度
const CURVE_TESSELLATE_PRECISION: int = 5

## 构建主线，返回是否成功
func build_main_line(
	hand_arrow: ArrowNode,
	player_arrow: ArrowNode,
	line: ArrowLine,
	parent_control: Control,
	global_offset: Vector2
) -> bool:
	line.kill_animation()
	var start: Vector2 = hand_arrow.get_tail_global()
	var end: Vector2 = player_arrow.get_tail_global()
	if start == end:
		return false
	var start_tangent_up: bool = not hand_arrow.direction.is_equal_approx(Vector2.UP)
	var end_tangent_up: bool = not player_arrow.direction.is_equal_approx(Vector2.UP)
	var curve: Curve2D = MathUtils.create_smooth_curve(start, end, start_tangent_up, end_tangent_up)
	line.points = curve.tessellate(CURVE_TESSELLATE_PRECISION)
	var offset: Vector2 = global_offset
	for i: int in line.points.size():
		line.points[i] -= offset
	line.start_animation(parent_control)
	return true

## 构建守区非我方牌指示线，返回是否成功
func build_enemy_line(
	target_player: RenderItem,
	render_context: RenderContext,
	enemy_line: ArrowLine,
	parent_control: Control,
	global_offset: Vector2
) -> bool:
	if not target_player or not target_player.data:
		return false
	var player_id: int = target_player.data.get_id()
	if player_id <= 0:
		return false
	var defence_area: RenderArea = render_context.get_render_area(RenderArea.DefaultArea.DEFENCE, player_id)
	if not defence_area:
		return false
	var preview_mode: Variant = defence_area.get_face_cache(&"nfn:preview_mode")
	if not preview_mode or preview_mode != true:
		return false
	var pool: Array = defence_area.items_pool
	if pool.is_empty():
		return false
	var local_id: int = render_context.area_manager.local_player_id if render_context and render_context.area_manager else 0
	var top_card: RenderItem = pool[-1]
	var second_card: RenderItem = pool[-2] if pool.size() >= 2 else null
	var selected_card: RenderItem = null
	var top_owner: int = (top_card.data as CardPack).player_id if top_card.data is CardPack else 0
	if top_owner != local_id and top_owner != 0:
		selected_card = top_card
	elif second_card:
		var second_owner: int = (second_card.data as CardPack).player_id if second_card.data is CardPack else 0
		if second_owner != local_id and second_owner != 0:
			selected_card = second_card
	if not selected_card:
		return false
	var owner_id: int = (selected_card.data as CardPack).player_id if selected_card.data is CardPack else 0
	if owner_id == 0:
		return false
	var owner_player: RenderItem = _get_player_by_id(render_context, owner_id)
	if not owner_player:
		return false

	enemy_line.kill_animation()
	var start: Vector2 = ArrowNode.get_card_top_center_global(selected_card)
	var end: Vector2 = ArrowNode.get_card_bottom_center_global(owner_player)
	var curve: Curve2D = MathUtils.create_smooth_curve(start, end, true, false)
	enemy_line.points = curve.tessellate(CURVE_TESSELLATE_PRECISION)
	var offset: Vector2 = global_offset
	for i: int in enemy_line.points.size():
		enemy_line.points[i] -= offset
	enemy_line.start_animation(parent_control)
	return true

func _get_player_by_id(render_context: RenderContext, player_id: int) -> RenderItem:
	if not render_context:
		return null
	var players_area: RenderArea = render_context.get_render_area(RenderArea.DefaultArea.PLAYERS)
	if not players_area:
		return null
	for item in players_area.items_pool:
		if item.data and item.data.get_id() == player_id:
			return item
	return null
