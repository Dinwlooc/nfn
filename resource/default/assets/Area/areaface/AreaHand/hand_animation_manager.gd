## 手牌动画：浮动相位（逐帧通道）与排布/交换/拖拽补间的静态装配。本类不创建 Tween、不持有槽位。
extends RefCounted

#==vars==
## 正弦表
var _sine_table: PackedFloat64Array = PackedFloat64Array()
## 全局相位索引
var _global_phase_index: int = 0

#==consts==
## 常量
const TABLE_SIZE: int = 64
## 每帧全局相位递增量
const PHASE_INCREMENT: int = 1
## 相位取模掩码（TABLE_SIZE-1）
const MASK: int = TABLE_SIZE - 1
## 相邻卡牌之间的相位差
const CARD_PHASE_OFFSET: int = 4
## 浮动振幅
const AMPLITUDE: float = 0.3
## 常规补间时长（秒）
const TWEEN_TIME: float = 0.2
## 拖拽补间时长（秒）
const DRAG_TWEEN_TIME: float = 0.1
## 复位时长（秒，常规补间的一半）
const RESET_TIME: float = TWEEN_TIME / 2.0
## 选中卡牌的竖直偏移
const SELECTED_Y_OFFSET: float = -40.0
## 中性缩放
const SCALE_NEUTRAL: float = 1.0
## 中性旋转
const ROTATION_NEUTRAL: float = 0.0
## 最大收缩比例
const MAX_SHRINK_FACTOR: float = 0.6
## 影响旋转的最大水平距离
const max_distance: float = 400.0
## 最大旋转角
const max_rotation: float = -PI * 0.167
## 旋转比例上限
const MAX_ROTATION_RATIO: float = 1.0
## 基准缩放
const BASE_SCALE_FACTOR: float = 1.0
## 正方向符号
const SIGN_POSITIVE: float = 1.0
## 负方向符号
const SIGN_NEGATIVE: float = -1.0

#==frame==
## 构造：生成正弦表
func _init() -> void:
	_generate_sine_table()
## 生成浮动用正弦表
## @internal
func _generate_sine_table() -> void:
	_sine_table = MathUtils.generate_sine_table(TABLE_SIZE)
## 卡牌浮动扩展效果（逐帧通道：不建补间、不占槽位）
## @internal
func card_move_expand(cards: Array[RenderItem]) -> void:
	_global_phase_index = (_global_phase_index + PHASE_INCREMENT) % TABLE_SIZE
	var card_count: int = cards.size()
	for i in card_count:
		var phase_index: int = (_global_phase_index + i * CARD_PHASE_OFFSET) & MASK
		var card: RenderItem = cards[i]
		if not card:
			continue
		card.position.y += AMPLITUDE * _sine_table[phase_index]

#==assembly==
## 排布补间：为每个非拖拽卡牌并行追加位置与缩放（已在目标位的不追加）。
## @atomic
static func do_card_layout(master_tween: Tween, cards: Array[RenderItem], target_position: PackedVector2Array, total_scale_factor: float) -> void:
	master_tween.set_parallel(true)
	for i in cards.size():
		var card: RenderItem = cards[i]
		if card.dragged:
			continue
		var target_scale: Vector2 = Vector2(total_scale_factor, total_scale_factor)
		var card_target_pos: Vector2 = target_position[i]
		if card.selected:
			card_target_pos.y += SELECTED_Y_OFFSET
		if card.position != card_target_pos:
			master_tween.tween_property(card, ^"position", card_target_pos, TWEEN_TIME) \
				.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
		if card.scale != target_scale:
			master_tween.tween_property(card, ^"scale", target_scale, TWEEN_TIME) \
				.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
## 交换特效补间：按水平位移追加旋转与横向缩放。
## @atomic
static func do_swap_effect(master_tween: Tween, cards: Array[RenderItem], target_position: PackedVector2Array, total_scale_factor: float) -> void:
	for i in cards.size():
		var card: RenderItem = cards[i]
		if card.dragged:
			continue
		var card_target_pos: Vector2 = target_position[i]
		var dx: float = card.position.x - card_target_pos.x
		var target_rot: float = _compute_rotation_from_dx(dx)
		var target_scale_x: float = total_scale_factor * _compute_scale_from_dx(dx)
		master_tween.tween_property(card, ^"rotation", target_rot, TWEEN_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		master_tween.tween_property(card, ^"scale:x", target_scale_x, TWEEN_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
## 复位补间：旋转归零、缩放回到总数因子。
## @atomic
static func do_layout_reset(master_tween: Tween, cards: Array[RenderItem], total_scale_factor: float) -> void:
	for card in cards:
		if card.dragged:
			continue
		master_tween.tween_property(card, ^"rotation", ROTATION_NEUTRAL, RESET_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		master_tween.tween_property(card, ^"scale", Vector2(total_scale_factor, total_scale_factor), RESET_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
## 拖拽跟随补间：跟鼠标走，随后回正旋转与缩放。
## @atomic
static func do_drag_follow(drag_tween: Tween, card: RenderItem, mouse_pos: Vector2, total_scale_factor: float) -> void:
	var dx: float = card.position.x - mouse_pos.x
	var target_rot: float = _compute_rotation_from_dx(dx)
	var target_scale_x: float = _compute_scale_from_dx(dx)
	drag_tween.set_parallel(true)
	drag_tween.tween_property(card, ^"center_position", mouse_pos, DRAG_TWEEN_TIME) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT_IN)
	drag_tween.tween_property(card, ^"rotation", target_rot, DRAG_TWEEN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	drag_tween.tween_property(card, ^"scale:x", target_scale_x, DRAG_TWEEN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	drag_tween.tween_property(card, ^"scale:y", SCALE_NEUTRAL, DRAG_TWEEN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	drag_tween.chain()
	drag_tween.tween_property(card, ^"rotation", ROTATION_NEUTRAL, RESET_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	drag_tween.tween_property(card, ^"scale:x", SCALE_NEUTRAL, RESET_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

#==pure==
## 根据水平位移差计算卡牌旋转角度
## @pure
static func _compute_rotation_from_dx(dx: float) -> float:
	var abs_dx: float = abs(dx)
	var rotation_ratio: float = min(abs_dx / max_distance, MAX_ROTATION_RATIO)
	var rotation_sign: float = SIGN_POSITIVE if dx < 0 else SIGN_NEGATIVE
	return rotation_sign * rotation_ratio * max_rotation
## 根据水平位移差计算卡牌水平缩放系数
## @pure
static func _compute_scale_from_dx(dx: float) -> float:
	var abs_dx: float = abs(dx)
	var rotation_ratio: float = min(abs_dx / max_distance, MAX_ROTATION_RATIO)
	return BASE_SCALE_FACTOR - rotation_ratio * MAX_SHRINK_FACTOR
