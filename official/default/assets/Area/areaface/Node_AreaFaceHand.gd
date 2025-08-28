extends RenderAreaFace

var original_position:Vector2
var original_size:Vector2
var area_target_position:Vector2
var area_target_size:Vector2
var swap_cooldown: float = 0.0
var pending_swap:bool = false
const SWAP_COOLDOWN_DURATION: float = 0.3
const SWAP_DELTA:float = 0.07
const TWEEN_TIME:float = 0.35

const TABLE_SIZE: int = 64  #采样点数量(2^N优化)，使用64保证能被4整除
const AMPLITUDE: float = 0.3
const PHASE_INCREMENT: int = 1     # 相位索引增量
const MASK: int = TABLE_SIZE - 1   # 位掩码用于快速取模
const CARD_PHASE_OFFSET: int = 4  # 卡牌间相位差
var _sine_table := PackedFloat64Array() # 类型化数组存储采样点
var _global_phase_index: int = 0

func ready_expand()->void:
	original_position = position
	original_size = size
	area_target_position = original_position
	area_target_size = original_size
	_generate_sine_table()
	
func _generate_sine_table() -> void:
	_sine_table.resize(TABLE_SIZE)
	var quarter = TABLE_SIZE / 4
	for i in range(0, quarter + 1):
		_sine_table[i] = sin(TAU * i / TABLE_SIZE)
	# 第二象限(π/2~π)
	for i in range(1, quarter):
		_sine_table[quarter + i] = _sine_table[quarter - i]
	# 第三四象限(π~2π)
	for i in range(0, 2 * quarter):
		_sine_table[2 * quarter + i] = -_sine_table[i]

func _physics_process(delta: float) -> void:
	if in_area:
		card_move_expand()
	elif Engine.get_process_frames() % 2 == 0:
		card_move_expand()
	if swap_cooldown > 0:
		swap_cooldown -= delta
		if pending_swap && swap_cooldown <= 0:
			swap_cards()
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
	card_move_rotate(card,_target_position)
	var tween =  UIAnimationUtils.tween_animations(card,{^"position":_target_position},TWEEN_TIME)
	tween.finished.connect(card_move_rotate.bind(card,_target_position))
	call_deferred(&"swap_cards")
	
func swap_cards()->void:
	if swap_cooldown > 0:
		if swap_cooldown < SWAP_COOLDOWN_DURATION - SWAP_DELTA:
			pending_swap = true
		return
	if  GlobalConsole.card_on_drag && GlobalConsole.card_on_drag.area == area:
		var drag_card = GlobalConsole.card_on_drag.card
		hover_detect_when_dragging(drag_card)
		if hovering_card:
			hovering_card.hovering = false
			area.move_card_to_index(drag_card.pool_id, hovering_card.pool_id,RenderEvent.new().set_config({&"rotate":true}))
			hovering_card = null
			swap_cooldown = SWAP_COOLDOWN_DURATION

func card_move_rotate(card:RenderCard, _target_position:Vector2)->void:
	# 计算水平距离差
	var dx = card.position.x - _target_position.x
	var abs_dx = abs(dx)
	const max_distance = 400.0
	const max_rotation = -PI*0.167
	const rotate_time = 0.5
	var rotation_ratio = min(abs_dx / max_distance, 1.0)
	var rotation_sign = 1.0 if dx < 0 else -1.0
	var _target_rotation = rotation_sign * rotation_ratio * max_rotation
	UIAnimationUtils.tween_animations(card, {^"rotation": _target_rotation}, rotate_time)

func card_move(render_event:RenderEvent = RenderEvent.new())-> void:
	if area.card_pool.size() == 0||target_position.size()==0:
		return
	for i in range(0,area.card_pool.size()):
		var card:RenderCard = area.card_pool[i]
		var card_position:Vector2 = card.position
		var _target_position:Vector2 = target_position[i]
		if card.selected:
			_target_position.y += -40.0
		if !card.dragged:
			if render_event.config.get(&"rotate"):
				card_move_rotate(card,_target_position)
				UIAnimationUtils.tween_animations(card,{^"position":_target_position},TWEEN_TIME).finished.connect(card_move_rotate.bind(card,_target_position))
			else:
				UIAnimationUtils.tween_animations(card,{^"position":_target_position},TWEEN_TIME)
	pass
