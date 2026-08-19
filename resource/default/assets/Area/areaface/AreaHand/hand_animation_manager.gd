## 手牌动画管理器：管理浮动、移动、拖拽动画及特效补间（纯逻辑，不创建 Tween）。
extends RefCounted

## 正弦表
var _sine_table: PackedFloat64Array = PackedFloat64Array()
## 全局相位索引
var _global_phase_index: int = 0

## 常量
const TABLE_SIZE: int = 64
const PHASE_INCREMENT: int = 1
const MASK: int = TABLE_SIZE - 1
const CARD_PHASE_OFFSET: int = 4
const AMPLITUDE: float = 0.3

const TWEEN_TIME: float = 0.2
const DRAG_TWEEN_TIME: float = 0.1
const RESET_TIME: float = TWEEN_TIME / 2.0

const SELECTED_Y_OFFSET: float = -40.0
const SCALE_NEUTRAL: float = 1.0
const ROTATION_NEUTRAL: float = 0.0
const MAX_SHRINK_FACTOR: float = 0.6
const max_distance: float = 400.0
const max_rotation: float = -PI * 0.167
const MAX_ROTATION_RATIO: float = 1.0
const BASE_SCALE_FACTOR: float = 1.0
const SIGN_POSITIVE: float = 1.0
const SIGN_NEGATIVE: float = -1.0

func _init() -> void:
	_generate_sine_table()

func _generate_sine_table() -> void:
	_sine_table = MathUtils.generate_sine_table(TABLE_SIZE)

## 卡牌浮动扩展效果（基于正弦表）
func card_move_expand(cards: Array) -> void:
	_global_phase_index = (_global_phase_index + PHASE_INCREMENT) % TABLE_SIZE
	var card_count: int = cards.size()
	for i in card_count:
		var phase_index: int = (_global_phase_index + i * CARD_PHASE_OFFSET) & MASK
		var card: RenderItem = cards[i]
		if not card:
			continue
		card.position.y += AMPLITUDE * _sine_table[phase_index]

## 核心动画调度函数（传入已创建的 master_tween）
func card_move(master_tween: Tween, cards: Array, target_position: Array, total_scale_factor: float, render_event: RenderEvent) -> void:
	if cards.is_empty() or target_position.is_empty():
		return
	master_tween.set_parallel(true)
	_add_base_movement_tweens(master_tween, cards, target_position, total_scale_factor)
	if render_event.get_type() == RenderEvent.DefaultType.SWAP_CARD:
		_add_swap_effect_tweens(master_tween, cards, target_position, total_scale_factor)
	master_tween.chain()
	_add_reset_tweens(master_tween, cards, total_scale_factor)

## 拖拽卡牌的动画处理（传入已创建的 drag_tween）
func dragging_move(drag_tween: Tween, card: RenderItem, mouse_pos: Vector2, total_scale_factor: float) -> void:
	var dx: float = card.position.x - mouse_pos.x
	var target_rot: float = _compute_rotation_from_dx(dx)
	var target_scale_x: float = _compute_scale_from_dx(dx)
	var target_scale_y: float = SCALE_NEUTRAL
	drag_tween.set_parallel(true)
	drag_tween.tween_property(card, ^"center_position", mouse_pos, DRAG_TWEEN_TIME) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT_IN)
	drag_tween.tween_property(card, ^"rotation", target_rot, DRAG_TWEEN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	drag_tween.tween_property(card, ^"scale:x", target_scale_x, DRAG_TWEEN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	drag_tween.tween_property(card, ^"scale:y", target_scale_y, DRAG_TWEEN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	drag_tween.chain()
	drag_tween.tween_property(card, ^"rotation", ROTATION_NEUTRAL, RESET_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	drag_tween.tween_property(card, ^"scale:x", SCALE_NEUTRAL, RESET_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## 为所有非拖拽卡牌添加基础位置移动动画（含总数缩放动画）
func _add_base_movement_tweens(master_tween: Tween, cards: Array, target_position: Array, total_scale_factor: float) -> void:
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

## 为交换事件添加旋转和缩放特效动画（scale.x 叠加总数因子）
func _add_swap_effect_tweens(master_tween: Tween, cards: Array, target_position: Array, total_scale_factor: float) -> void:
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

## 恢复所有卡牌的默认旋转和缩放（恢复到总数因子）
func _add_reset_tweens(master_tween: Tween, cards: Array, total_scale_factor: float) -> void:
	for card in cards:
		if card.dragged:
			continue
		master_tween.tween_property(card, ^"rotation", ROTATION_NEUTRAL, RESET_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		var target_scale: Vector2 = Vector2(total_scale_factor, total_scale_factor)
		master_tween.tween_property(card, ^"scale", target_scale, RESET_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## 根据水平位移差计算卡牌旋转角度（纯函数）
func _compute_rotation_from_dx(dx: float) -> float:
	var abs_dx: float = abs(dx)
	var rotation_ratio: float = min(abs_dx / max_distance, MAX_ROTATION_RATIO)
	var rotation_sign: float = SIGN_POSITIVE if dx < 0 else SIGN_NEGATIVE
	return rotation_sign * rotation_ratio * max_rotation

## 根据水平位移差计算卡牌水平缩放系数（纯函数）
func _compute_scale_from_dx(dx: float) -> float:
	var abs_dx: float = abs(dx)
	var rotation_ratio: float = min(abs_dx / max_distance, MAX_ROTATION_RATIO)
	return BASE_SCALE_FACTOR - rotation_ratio * MAX_SHRINK_FACTOR
