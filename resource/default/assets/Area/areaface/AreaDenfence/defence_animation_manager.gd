## 守区动画：卡牌移动/缩放/旋转的静态装配与预览几何计算。本类不创建 Tween、不持有槽位。
## 普通模式使用局部坐标，预览模式使用全局坐标。
extends RefCounted

#==consts==
## 预览动画时长（秒）
const PREVIEW_ANIM_TIME: float = 0.45
## 常规补间动画时长（秒）
const TWEEN_TIME: float = 0.2
## 重置动画时长（秒）
const RESET_TIME: float = TWEEN_TIME / 2.0
## 中性缩放值
const SCALE_NEUTRAL: float = 1.0
## 中性旋转角度（弧度）
const ROTATION_NEUTRAL: float = 0.0
## 预览顶层放大系数
const PREVIEW_TOP_SCALE: float = 1.2
## 预览次层缩小系数
const PREVIEW_SECOND_SCALE: float = 0.8
## 预览水平线竖直偏移（全局像素，向下为正）
const PREVIEW_HORIZONTAL_LINE_Y_OFFSET: float = -40.0
## 预览水平线长度缩放比（相对屏幕宽度）
const PREVIEW_HORIZONTAL_LINE_SCALE: float = 0.2
## 浮动振幅（像素）
const FLOAT_AMPLITUDE: float = 8.0
## 浮动周期（秒）
const FLOAT_PERIOD: float = 1.8
## 每张卡相位偏移增量（弧度）
const FLOAT_PHASE_OFFSET: float = 0.5

#==record==
## 预览参数记录类（预览是否生效、顶层与次层的落点与缩放，六项总是成组使用）。
## @record
class PreviewParams:
	## 预览是否生效
	var active: bool
	## 顶层卡牌全局坐标
	var top_global: Vector2
	## 次层卡牌全局坐标（若无次层则无效）
	var second_global: Vector2
	## 顶层卡牌缩放值
	var top_scale: float
	## 次层卡牌缩放值
	var second_scale: float
	## 是否存在次层卡牌
	var has_second: bool

	## 构造：记录预览开关、顶部/第二张牌的全局位置、缩放与是否存在第二张
	func _init(p_active: bool, p_top_global: Vector2, p_second_global: Vector2, p_top_scale: float, p_second_scale: float, p_has_second: bool) -> void:
		active = p_active
		top_global = p_top_global
		second_global = p_second_global
		top_scale = p_top_scale
		second_scale = p_second_scale
		has_second = p_has_second

#==pure==
## 计算单张卡牌的浮动垂直偏移量
## @pure
static func get_float_offset(card_index: int, elapsed: float) -> float:
	return sin(elapsed * 2.0 * PI / FLOAT_PERIOD + card_index * FLOAT_PHASE_OFFSET) * FLOAT_AMPLITUDE
## 计算预览落点（全局坐标）与缩放；未启用预览时返回 active=false 的记录。
## @pure
static func compute_preview_params(cards: Array[RenderItem], local_player_id: int, viewport: Viewport, preview_active: bool) -> PreviewParams:
	var size: int = cards.size()
	if not preview_active or size == 0 or not viewport:
		return PreviewParams.new(false, Vector2.ZERO, Vector2.ZERO, 1.0, 1.0, false)
	var rect: Rect2 = viewport.get_visible_rect()
	var center: Vector2 = rect.size / 2.0
	var line_y: float = center.y + PREVIEW_HORIZONTAL_LINE_Y_OFFSET
	var half_line: float = rect.size.x * PREVIEW_HORIZONTAL_LINE_SCALE * 0.5
	var right_global: Vector2 = Vector2(center.x + half_line, line_y)
	var left_global: Vector2 = Vector2(center.x - half_line, line_y)
	var aux_global: Vector2 = Vector2(center.x, line_y)
	if size == 1:
		return PreviewParams.new(true, aux_global, Vector2.ZERO, 1.0, 1.0, false)
	var top_card: RenderItem = cards[size - 1]
	var second_card: RenderItem = cards[size - 2]
	var top_owner: int = (top_card.data as CardPack).player_id if top_card.data is CardPack else 0
	var second_owner: int = (second_card.data as CardPack).player_id if second_card.data is CardPack else 0
	var same_owner: bool = (top_owner == second_owner)
	var top_scale_val: float = PREVIEW_TOP_SCALE
	var second_scale_val: float = PREVIEW_SECOND_SCALE
	if same_owner:
		var main_global: Vector2 = right_global if top_owner == local_player_id else left_global
		return PreviewParams.new(true, main_global, aux_global, top_scale_val, second_scale_val, true)
	if top_owner == local_player_id:
		return PreviewParams.new(true, right_global, left_global, top_scale_val, second_scale_val, true)
	if second_owner == local_player_id:
		return PreviewParams.new(true, left_global, right_global, top_scale_val, second_scale_val, true)
	return PreviewParams.new(true, right_global, left_global, top_scale_val, second_scale_val, true)

#==assembly==
## 守区排布补间：按池内顺序为每张非拖拽卡牌追加落点与缩放，并回正旋转。
## @atomic
static func do_card_layout(
	master_tween: Tween,
	cards: Array[RenderItem],
	target_local_positions: Array[Vector2],
	total_scale_factor: float,
	preview: PreviewParams
) -> void:
	master_tween.set_parallel(true)
	var pool_size: int = cards.size()
	for i in pool_size:
		var card: RenderItem = cards[i]
		if card.dragged:
			continue
		_do_single_card(master_tween, card, i, target_local_positions[i], total_scale_factor, preview, pool_size)

#==internal==
## 为单张卡牌追加补间（预览顶层/次层走全局坐标，其余走局部坐标）。
## @internal
static func _do_single_card(
	master_tween: Tween,
	card: RenderItem,
	index: int,
	target_local: Vector2,
	total_scale_factor: float,
	preview: PreviewParams,
	pool_size: int
) -> void:
	var anim_time: float = TWEEN_TIME
	var scale_target: Vector2 = Vector2(total_scale_factor, total_scale_factor)
	var is_preview_top: bool = preview.active and (index == pool_size - 1)
	var is_preview_second: bool = preview.active and (index == pool_size - 2) and preview.has_second
	if is_preview_top or is_preview_second:
		anim_time = PREVIEW_ANIM_TIME
		var global_target: Vector2
		var scale_val: float
		if is_preview_top:
			global_target = preview.top_global
			scale_val = preview.top_scale
		else:
			global_target = preview.second_global
			scale_val = preview.second_scale
		scale_target = Vector2.ONE * scale_val
		global_target += card.get_centered_offset(scale_target)
		if card.global_position != global_target:
			master_tween.tween_property(card, ^"global_position", global_target, anim_time) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		var card_local_target: Vector2 = target_local + card.get_centered_offset(scale_target)
		if card.position != card_local_target:
			master_tween.tween_property(card, ^"position", card_local_target, anim_time) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if card.scale != scale_target:
		master_tween.tween_property(card, ^"scale", scale_target, anim_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	master_tween.tween_property(card, ^"rotation", ROTATION_NEUTRAL, RESET_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
