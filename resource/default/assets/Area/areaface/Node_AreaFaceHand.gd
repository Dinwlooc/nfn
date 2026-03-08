extends AreaFace

## 原始位置（未展开时的锚点）
var original_position: Vector2
## 原始尺寸
var original_size: Vector2
## 目标位置（动画过渡用）
var area_target_position: Vector2
## 目标尺寸
var area_target_size: Vector2
## 上次成功交换的毫秒时间戳（用于冷却判断）
var last_swap_time_ms: int = 0
## 是否有等待中的交换请求
var pending_swap: bool = false
## 当前卡牌群组动画的 Tween 实例
var current_card_tween: Tween = null
## 当前拖拽动画的 Tween 实例
var current_drag_tween: Tween = null
## 交换冷却持续时间（毫秒）
const SWAP_COOLDOWN_DURATION_MS: int = 300
## 交换允许延迟触发的时间窗口（毫秒），距离上次交换间隔此时间后，允许缓存请求
const SWAP_DELTA_MS: int = 70
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
## 选中卡牌的 Y 轴偏移量（向上抬起）
const SELECTED_Y_OFFSET: float = -40.0
## 中性缩放值（无缩放时的基准）
const SCALE_NEUTRAL: float = 1.0
## 中性旋转值（无旋转）
const ROTATION_NEUTRAL: float = 0.0
## 展开动画中区域移动的位移长度
const EXPAND_MOVE_LENGTH: float = 150.0
## 旋转比例上限（最大 100%）
const MAX_ROTATION_RATIO: float = 1.0
## 缩放计算中的基础系数
const BASE_SCALE_FACTOR: float = 1.0
## 正方向符号
const SIGN_POSITIVE: float = 1.0
## 负方向符号
const SIGN_NEGATIVE: float = -1.0

@onready var ui_container = $UIContainer
@onready var quick_sort_ui = $UIContainer/QuickSortUI
@onready var quick_sort_button = $UIContainer/QuickSortUI/QuickSortButton
@onready var play_card_ui = $UIContainer/PlayCardUI
@onready var play_card_button = $UIContainer/PlayCardUI/PlayCardButton

## 预计算的正弦表
var _sine_table: PackedFloat64Array = PackedFloat64Array()
## 全局相位索引
var _global_phase_index: int = 0
var is_sorting: bool = false
## 当前卡牌总数决定的缩放因子（16张以下为1.0，32张时为0.75）
var total_scale_factor: float = 1.0
var _order_dirty: bool = true

func _ready() -> void:
	request_area(RenderArea.DefaultArea.HAND)
	original_position = position
	original_size = size
	area_target_position = original_position
	area_target_size = original_size
	quick_sort_button.pressed.connect(_on_quick_sort_button_pressed)
	ui_container.hide()  # 初始隐藏
	_generate_sine_table()
	_update_total_scale_factor()  # 初始化缩放因子
	last_swap_time_ms = -SWAP_COOLDOWN_DURATION_MS
	play_card_button.pressed.connect(_on_play_card_button_pressed)
	play_card_ui.visible = false  # 初始隐藏

## 根据卡牌数量更新缩放
func _update_total_scale_factor() -> void:
	if not area:
		return
	var count: int = area.items_pool.size()
	if count <= 8:
		total_scale_factor = SCALE_NEUTRAL
	elif count >= 24:
		total_scale_factor = 0.75
	else:
		total_scale_factor = SCALE_NEUTRAL - (count - 8) / 16.0 * 0.25

## 生成正弦波采样表（函数式，无副作用）
func _generate_sine_table() -> void:
	_sine_table = MathUtils.generate_sine_table(TABLE_SIZE)

func _physics_process(delta: float) -> void:
	if in_area:
		card_move_expand()
	elif Engine.get_process_frames() % 2 == 0:
		card_move_expand()
	if pending_swap && can_swap_immediately(Time.get_ticks_msec()):
		try_dragging_move()      # 基类方法，重新判断拖拽卡牌方位和悬停
		pending_swap = false

## 更新渲染目标位置
func render_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	var event_type:StringName = render_event.get_type()
	if event_type == RenderEvent.DefaultType.CARD_ADD or event_type == RenderEvent.DefaultType.CARD_REMOVE:
		_update_total_scale_factor()
		_order_dirty = true
	target_position = UIAnimationUtils.generate_coordinates(area_target_position, area_target_size, area.items_pool.size())
	tween_update(render_event)

## 触发卡牌移动动画
func tween_update(render_event: RenderEvent = RenderEvent.NULL_EVENT) -> void:
	var event_type:StringName = render_event.get_type()
	if event_type == RenderEvent.DefaultType.SWAP_CARD:
		_order_dirty = true
	if event_type == RenderEvent.DefaultType.CARD_SELECTION_CHANGED:
		play_card_ui.visible = not area.get_selected_items().is_empty()
	card_move(render_event)

## 进入区域时的展开动画
func _into_area() -> void:
	super._into_area()
	area_target_position = original_position - Vector2(0, EXPAND_MOVE_LENGTH)
	area_target_size = original_size + Vector2(0, EXPAND_MOVE_LENGTH)
	var list: Dictionary[NodePath, Variant] = {
		^"position": area_target_position,
		^"size": area_target_size,
	}
	UIAnimationUtils.tween_animations(self, list, TWEEN_TIME)
	ui_container.show()
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
	ui_container.hide()
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
	var target_scale_x: float = _compute_scale_from_dx(dx)  # 动态收缩，不乘总数因子
	var target_scale_y: float = SCALE_NEUTRAL               # 恢复原始比例
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
	current_drag_tween.tween_property(card, ^"scale:y", target_scale_y, DRAG_TWEEN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	current_drag_tween.chain()
	current_drag_tween.tween_property(card, ^"rotation", ROTATION_NEUTRAL, RESET_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	current_drag_tween.tween_property(card, ^"scale:x", SCALE_NEUTRAL, RESET_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	swap_cards(card)

## 判断是否可以立即执行交换（纯函数）
func can_swap_immediately(current_time_ms: int) -> bool:
	return current_time_ms - last_swap_time_ms >= SWAP_COOLDOWN_DURATION_MS

## 判断是否应该缓存交换请求（纯函数）
func should_cache_request(current_time_ms: int) -> bool:
	var time_since_last_ms:int = current_time_ms - last_swap_time_ms
	return time_since_last_ms > SWAP_DELTA_MS and time_since_last_ms < SWAP_COOLDOWN_DURATION_MS

## 尝试交换拖拽卡牌与悬停卡牌
func swap_cards(drag_card: RenderItem) -> void:
	var current_time_ms:int = Time.get_ticks_msec()
	if !can_swap_immediately(current_time_ms):
		if should_cache_request(current_time_ms):
			pending_swap = true
		return
	if not hovering_card:
		return
	hovering_card.set_hovering(false)
	area.move_item_to_index(drag_card.pool_id, hovering_card.pool_id, RenderEvent.new(RenderEvent.DefaultType.SWAP_CARD))
	hovering_card = null
	last_swap_time_ms = current_time_ms


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

## 为所有非拖拽卡牌添加基础位置移动动画（含总数缩放动画）
func _add_base_movement_tweens(master_tween: Tween) -> void:
	for i in area.items_pool.size():
		var card: RenderItem = area.items_pool[i]
		if card.dragged:
			continue
		var card_target_pos: Vector2 = target_position[i]
		if card.selected:
			card_target_pos.y += SELECTED_Y_OFFSET
		if card.position != card_target_pos:
			master_tween.tween_property(card, ^"position", card_target_pos, TWEEN_TIME) \
				.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
		var target_scale: Vector2 = Vector2(total_scale_factor, total_scale_factor)
		if card.scale != target_scale:
			master_tween.tween_property(card, ^"scale", target_scale, TWEEN_TIME) \
				.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)

## 为交换事件添加旋转和缩放特效动画（scale.x 叠加总数因子）
func _add_swap_effect_tweens(master_tween: Tween) -> void:
	for i in area.items_pool.size():
		var card: RenderItem = area.items_pool[i]
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
func _add_reset_tweens(master_tween: Tween) -> void:
	for card in area.items_pool:
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

# 按钮按下时的处理（设置冷却）
func _on_quick_sort_button_pressed() -> void:
	if not _order_dirty:
		return
	if is_sorting:
		return
	is_sorting = true
	quick_sort_button.disabled = true
	await _quick_sort_cards()
	is_sorting = false
	quick_sort_button.disabled = false

func _quick_sort_cards() -> void:
	var pool: Array[RenderItem] = area.items_pool
	var attack_end: int = 0  # 下一个攻击牌插入位置
	var defence_end: int = 0 # 下一个防御牌插入位置
	for i in pool.size():
		if pool[i].data.get_card_type() == &"attack":
			if i == attack_end:
				attack_end += 1
				continue
			area.swap_items_no_event(i, attack_end)
			attack_end += 1
		if pool[i].data.get_card_type() == &"defence":
			if defence_end == 0:
				defence_end = attack_end #校准起点
			if i == defence_end:
				defence_end += 1
				continue
			area.swap_items_no_event(i, defence_end)
			defence_end += 1
		if pool[i].data.get_card_type() == &"spell":
			continue
	area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.SWAP_CARD))
	await get_tree().create_timer(TWEEN_TIME).timeout
	sort_region(0, attack_end - 1)                # 攻击区
	sort_region(attack_end, defence_end - 1)      # 防御区
	sort_region(defence_end, pool.size() - 1)            # 技能区
	area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.SWAP_CARD))
	_order_dirty = false

func sort_region(start: int, end: int) -> void:
	var pool = area.items_pool
	for i in range(start + 1, end + 1):
		var j = i
		while j > start and pool[j].data.id < pool[j-1].data.id:
			area.swap_items_no_event(j, j-1)
			j -= 1

func _on_play_card_button_pressed() -> void:
	var op_manager:OperationManager= render_context.get_operation_manager()
	var event:RenderEvent = op_manager.upload_play_card()
