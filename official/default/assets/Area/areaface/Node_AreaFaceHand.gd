extends RenderAreaFace

var original_position:Vector2
var original_size:Vector2
var area_target_position:Vector2
var area_target_size:Vector2
var swap_cooldown: float = 0.0
var pending_swap:bool = false
var current_card_tween: Tween = null
var current_drag_tween: Tween = null
const SWAP_COOLDOWN_DURATION: float = 0.3
const SWAP_DELTA:float = 0.07
const TWEEN_TIME:float = 0.2
const DRAG_TWEEN_TIME:float = 0.1
const RESET_TIME:float = TWEEN_TIME / 2.0

const TABLE_SIZE: int = 64  #采样点数量(2^N)
const AMPLITUDE: float = 0.3
const PHASE_INCREMENT: int = 1     # 相位索引增量
const MASK: int = TABLE_SIZE - 1   # 位掩码用于快速取模
const CARD_PHASE_OFFSET: int = 4  # 卡牌间相位差
const max_distance = 400.0
const max_rotation = -PI*0.167

var _sine_table := PackedFloat64Array() # 类型化数组存储采样点
var _global_phase_index: int = 0

func ready_expand()->void:
	original_position = position
	original_size = size
	area_target_position = original_position
	area_target_size = original_size
	_generate_sine_table()

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

func render_update(render_event:RenderEvent = RenderEvent.new())->void:
	target_position = UIAnimationUtils.generate_coordinates(area_target_position,area_target_size,area.card_pool.size())
	tween_update(render_event)

func tween_update(render_event:RenderEvent = RenderEvent.new())->void:
	card_move(render_event)

func _into_area()->void:
	const MOVE_LENGTH:float= 100
	area_target_position = original_position - Vector2(0, MOVE_LENGTH)
	area_target_size = original_size + Vector2(0, MOVE_LENGTH)
	var list:Dictionary[NodePath,Variant] = {
		^"position":area_target_position,
		^"size":area_target_size,
		}
	UIAnimationUtils.tween_animations(self,list,TWEEN_TIME)
	area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.INTO_AREA))
	pass

func _outto_area()->void:
	area_target_position = original_position
	area_target_size = original_size
	var list:Dictionary[NodePath,Variant] = {
		^"position":area_target_position,
		^"size":area_target_size,
		}
	UIAnimationUtils.tween_animations(self,list,TWEEN_TIME)
	area.render_requested.emit(RenderEvent.new(RenderEvent.DefaultType.OUTTO_AREA))

func card_move_expand() -> void:
	_global_phase_index = (_global_phase_index + PHASE_INCREMENT) % TABLE_SIZE
	var cards = area.card_pool
	var card_count = cards.size()
	for i in card_count:
		var phase_index = (_global_phase_index + i * CARD_PHASE_OFFSET) & MASK
		cards[i].position.y += AMPLITUDE * _sine_table[phase_index]

func dragging_move(card:RenderCard)->void:
	var _target_position = get_global_mouse_position()
	if current_drag_tween:
		current_drag_tween.kill()
	current_drag_tween = create_tween()
	current_drag_tween.set_parallel(true)
	var target_rot = _compute_rotation(card, _target_position)
	current_drag_tween.tween_property(card, ^"position", _target_position, DRAG_TWEEN_TIME) \
		.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT_IN)
	current_drag_tween.tween_property(card, ^"rotation", target_rot, DRAG_TWEEN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	current_drag_tween.chain()
	current_drag_tween.tween_property(card, ^"rotation", 0.0, RESET_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	swap_cards(card)

func swap_cards(drag_card:RenderCard)->void:
	if swap_cooldown > 0:
		if swap_cooldown < SWAP_COOLDOWN_DURATION - SWAP_DELTA:
			pending_swap = true
		return
	if hovering_card:
		hovering_card.hovering = false
		area.move_card_to_index(drag_card.pool_id, hovering_card.pool_id,RenderEvent.new().set_config({&"rotate":true}))
		hovering_card = null
		swap_cooldown = SWAP_COOLDOWN_DURATION

func card_move(render_event:RenderEvent = RenderEvent.new())-> void:
	if area.card_pool.size() == 0 || target_position.size() == 0:
		return
	var master_tween:Tween = create_tween()
	master_tween.set_parallel(true)
	for i in range(area.card_pool.size()):
		var card:RenderCard = area.card_pool[i]
		var card_target_pos:Vector2 = target_position[i]
		if card.selected:
			card_target_pos.y += -40.0
		if !card.dragged:
			master_tween.tween_property(card, ^"position", card_target_pos, TWEEN_TIME) \
				.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
			if render_event.config.get(&"rotate"):
				var target_rot = _compute_rotation(card, card_target_pos)
				master_tween.tween_property(card, ^"rotation", target_rot, TWEEN_TIME) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# === 阶段2: 并行执行所有卡牌的旋转复位 ===
	master_tween.chain()
	for card in area.card_pool:
		if !card.dragged:
			master_tween.tween_property(card, ^"rotation", 0.0, RESET_TIME) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if current_card_tween:
		current_card_tween.kill()
	current_card_tween = master_tween
# 新增辅助函数：仅计算旋转值不执行动画
func _compute_rotation(card:RenderCard, _target_position:Vector2) -> float:
	var dx = card.position.x - _target_position.x
	var abs_dx = abs(dx)
	var rotation_ratio = min(abs_dx / max_distance, 1.0)
	var rotation_sign = 1.0 if dx < 0 else -1.0
	return rotation_sign * rotation_ratio * max_rotation
