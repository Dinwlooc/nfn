## 卡牌区域管理类，负责卡牌布局、动画及交换逻辑。
extends AreaFace

## 原始位置（未展开时的锚点）
var original_position: Vector2
## 原始尺寸
var original_size: Vector2
## 目标位置（动画过渡用）
var area_target_position: Vector2
## 目标尺寸
var area_target_size: Vector2
## 交换冷却计时器
var swap_cooldown: float = 0.0
## 是否有等待中的交换请求
var pending_swap: bool = false
## 当前卡牌群组动画的 Tween 实例
var current_card_tween: Tween = null
## 当前拖拽动画的 Tween 实例
var current_drag_tween: Tween = null
## 交换冷却持续时间（秒）
const SWAP_COOLDOWN_DURATION: float = 0.3
## 交换允许延迟触发的时间窗口
const SWAP_DELTA: float = 0.07
## 常规补间动画时长
const TWEEN_TIME: float = 0.2
## 拖拽补间动画时长
const DRAG_TWEEN_TIME: float = 0.1
## 重置动画时长（通常为 TWEEN_TIME 的一半）
const RESET_TIME: float = TWEEN_TIME / 2.0
## 正弦波采样点数量（2^N）
const TABLE_SIZE: int = 64
## 波动幅度
const AMPLITUDE: float = 0.3
## 全局相位增量
const PHASE_INCREMENT: int = 1
## 位掩码（用于快速取模）
const MASK: int = TABLE_SIZE - 1
## 卡牌间相位差
const CARD_PHASE_OFFSET: int = 4
## 旋转效果的最大位移阈值
const max_distance: float = 400.0
## 最大旋转角度
const max_rotation: float = -PI * 0.167
## 最大水平收缩系数
const MAX_SHRINK_FACTOR: float = 0.6
## 预计算的正弦表
var _sine_table: PackedFloat64Array = PackedFloat64Array()
## 全局相位索引
var _global_phase_index: int = 0

func _ready() -> void:
	request_area(RenderArea.DefaultArea.HAND)
	original_position = position
	original_size = size
	area_target_position = original_position
	area_target_size = original_size
	_generate_sine_table()
## 生成正弦波采样表（函数式，无副作用）
func _generate_sine_table() -> void:
	_sine_table = MathUtils.generate_sine_table(TABLE_SIZE)

func _physics_process(delta: float) -> void:
	if in_area:
		card_move_expand()
	elif Engine.get_process_frames() % 2 == 0:
		card_move_expand()
	if swap_cooldown > 0:
		swap_cooldown -= delta
		if pending_swap && swap_cooldown <= 0:
			try_dragging_move()
			pending_swap = false
## 更新渲染目标位置
func render_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	target_position = UIAnimationUtils.generate_coordinates(area_target_position, area_target_size, area.items_pool.size())
	tween_update(render_event)
## 触发卡牌移动动画
func tween_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	card_move(render_event)
## 进入区域时的展开动画
func _into_area() -> void:
	super._into_area()
	const MOVE_LENGTH: float = 150
	area_target_position = original_position - Vector2(0, MOVE_LENGTH)
	area_target_size = original_size + Vector2(0, MOVE_LENGTH)
	var list: Dictionary[NodePath, Variant] = {
		^"position": area_target_position,
		^"size": area_target_size,
	}
	UIAnimationUtils.tween_animations(self, list, TWEEN_TIME)
	area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.INTO_AREA))
## 离开区域时的收起动画
func _outto_area() -> void:
	super._outto_area()
	area_target_position = original_position
	area_target_size = original_size
	var list: Dictionary[NodePath, Variant] = {
		^"position": area_target_position,
		^"size": area_target_size,
	}
	UIAnimationUtils.tween_animations(self, list, TWEEN_TIME)
	area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.OUTTO_AREA))
## 卡牌浮动扩展效果（基于正弦表）
func card_move_expand() -> void:
	_global_phase_index = (_global_phase_index + PHASE_INCREMENT) % TABLE_SIZE
	var cards: Array = area.items_pool
	var card_count: int = cards.size()
	for i in card_count:
		var phase_index: int = (_global_phase_index + i * CARD_PHASE_OFFSET) & MASK
		cards[i].position.y += AMPLITUDE * _sine_table[phase_index]
## 拖拽卡牌的动画处理
func dragging_move(card: RenderItem) -> void:
	var _target_position: Vector2 = get_global_mouse_position()
	var dx: float = card.position.x - _target_position.x
	var target_rot: float = _compute_rotation_from_dx(dx)
	var target_scale_x: float = _compute_scale_from_dx(dx)
	if current_drag_tween:
		current_drag_tween.kill()
	current_drag_tween = create_tween()
	current_drag_tween.set_parallel(true)
	current_drag_tween.tween_property(card, ^"position", _target_position, DRAG_TWEEN_TIME) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT_IN)
	current_drag_tween.tween_property(card, ^"rotation", target_rot, DRAG_TWEEN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	current_drag_tween.tween_property(card, ^"scale:x", target_scale_x, DRAG_TWEEN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	current_drag_tween.chain()
	current_drag_tween.tween_property(card, ^"rotation", 0.0, RESET_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	current_drag_tween.tween_property(card, ^"scale:x", 1.0, RESET_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	swap_cards(card)

## 尝试交换拖拽卡牌与悬停卡牌（使用卫语句简化）
func swap_cards(drag_card: RenderItem) -> void:
	if swap_cooldown > 0 && swap_cooldown < SWAP_COOLDOWN_DURATION - SWAP_DELTA:
		pending_swap = true
		return
	if not hovering_card:
		return
	hovering_card.hovering = false
	hovering_card.render_update()
	area.move_item_to_index(drag_card.pool_id, hovering_card.pool_id, RenderEvent.new(RenderEvent.DefaultType.SWAP_CARD))
	hovering_card = null
	swap_cooldown = SWAP_COOLDOWN_DURATION

## 核心动画调度函数（已拆分辅助函数）
func card_move(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	if area.items_pool.is_empty() or target_position.is_empty():
		return
	var master_tween: Tween = create_tween()
	master_tween.set_parallel(true)
	_add_base_movement_tweens(master_tween)
	if render_event.get_type() == RenderEvent.DefaultType.SWAP_CARD:
		_add_swap_effect_tweens(master_tween)
	master_tween.chain()
	_add_reset_tweens(master_tween)
	if current_card_tween:
		current_card_tween.kill()
	current_card_tween = master_tween

## 为所有非拖拽卡牌添加基础位置移动动画
func _add_base_movement_tweens(master_tween: Tween) -> void:
	for i in area.items_pool.size():
		var card: RenderItem = area.items_pool[i]
		if card.dragged:
			continue
		var card_target_pos: Vector2 = target_position[i]
		if card.selected:
			card_target_pos.y += -40.0
		if card.position == card_target_pos:
			continue
		master_tween.tween_property(card, ^"position", card_target_pos, TWEEN_TIME) \
			.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)

## 为交换事件添加旋转和缩放特效动画
func _add_swap_effect_tweens(master_tween: Tween) -> void:
	for i in area.items_pool.size():
		var card: RenderItem = area.items_pool[i]
		if card.dragged:
			continue
		var card_target_pos: Vector2 = target_position[i]
		var dx: float = card.position.x - card_target_pos.x
		var target_rot: float = _compute_rotation_from_dx(dx)
		var target_scale_x: float = _compute_scale_from_dx(dx)
		master_tween.tween_property(card, ^"rotation", target_rot, TWEEN_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		master_tween.tween_property(card, ^"scale:x", target_scale_x, TWEEN_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

## 最后恢复所有卡牌的默认旋转和缩放
func _add_reset_tweens(master_tween: Tween) -> void:
	for card in area.items_pool:
		if card.dragged:
			continue
		master_tween.tween_property(card, ^"rotation", 0.0, RESET_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		master_tween.tween_property(card, ^"scale:x", 1.0, RESET_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## 根据水平位移差计算卡牌旋转角度（纯函数）
func _compute_rotation_from_dx(dx: float) -> float:
	var abs_dx: float = abs(dx)
	var rotation_ratio: float = min(abs_dx / max_distance, 1.0)
	var rotation_sign: float = 1.0 if dx < 0 else -1.0
	return rotation_sign * rotation_ratio * max_rotation

## 根据水平位移差计算卡牌水平缩放系数（纯函数）
func _compute_scale_from_dx(dx: float) -> float:
	var abs_dx: float = abs(dx)
	var rotation_ratio: float = min(abs_dx / max_distance, 1.0)
	return 1.0 - rotation_ratio * MAX_SHRINK_FACTOR
