extends Control
class_name RenderArea
#总控区域渲染与交互。

var area_name:StringName
@export var control:RenderControl
var card_pool:Array[RenderCard]
@export var card_id_to_instance: Dictionary[int,RenderCard] = {}
var selected_cards: Array[RenderCard] = []
var select_limit:int = 1
var init_child_count:int
signal render_requested(render_event:RenderEvent)
signal tween_requested(render_event:RenderEvent)
signal selected()
signal cards_add_requested(cards:Array[CardPack])
signal cards_added(cards:Array[RenderCard])
signal cards_remove_requested(uids:PackedInt32Array)
signal card_move_requested(card: RenderCard, new_index: int)
class DefaultArea:
	const HAND:StringName = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.HAND]
	const PLAYERS:StringName = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.PLAYERS]

func _ready():
	init_child_count = get_child_count()
	ready_expand()
	pass

func ready_expand()->void:
	pass

func render_update(render_event:RenderEvent = RenderEvent.new())-> void:
	render_requested.emit(render_event)
	pass

func tween_update(render_event:RenderEvent = RenderEvent.new())->void:
	tween_requested.emit(render_event)
	pass

func process_request(request)->void:
	if request is RenderRequest.CardAdd:
		cards_add_requested.emit(request.card_data)
	elif request is RenderRequest.CardRemove:
		cards_remove_requested.emit(request.uids_data)

func add_card_to_pool(card: RenderCard, index: int) -> void:
	card.pool_id = index
	if index >= card_pool.size():
		card_pool.append(card)
	else:
		card_pool[index] = card
func remove_cards_by_uids(uids: PackedInt32Array) -> Array[RenderCard]:
	var removed_cards: Array[RenderCard] = []
	var min_index := -1

	# 收集需要移除的卡牌并更新内部状态
	for uid in uids:
		if card_id_to_instance.has(uid):
			var card = card_id_to_instance[uid]
			removed_cards.append(card)
			var pool_id = card.pool_id
			if min_index == -1 || pool_id < min_index:
				min_index = pool_id
			if card in selected_cards:
				selected_cards.erase(card)
			card_id_to_instance.erase(uid)
			card_pool[pool_id] = null
	if min_index != -1:
		compact_pool(min_index, uids.size())
	return removed_cards
func compact_pool(min_index: int, removed_count: int) -> void:
	if min_index + removed_count > card_pool.size():
		card_pool.resize(min_index)
		return
	var write_index = min_index
	for read_index in range(min_index + 1, card_pool.size()):
		var card = card_pool[read_index]
		if card == null:
			continue
		update_card_position(card, write_index)
		card_pool[write_index] = card
		write_index += 1
	card_pool.resize(write_index)
	render_update()

func on_select(card: RenderCard) -> void:
	if card.selected:
		card.selected = false
		selected_cards.erase(card)  # 精确移除实例
	else:
		if selected_cards.size() >= select_limit:
			selected_cards[0].selected = false
			selected_cards.remove_at(0)
		card.selected = true
		selected_cards.append(card)
	tween_update()
	selected.emit()

func on_drag(pool_id:int)->void:
	if !control :
		return
	if Input.get_mouse_button_mask()==1:
		control.set_card_on_drag(self,card_pool[pool_id])
	else:
		control.remove_card_on_drag()
	pass

func get_selected_cards()->Array[RenderCard]:
	return selected_cards

func get_selected_ids() -> PackedInt32Array:
	var ids = PackedInt32Array()
	ids.resize(selected_cards.size())
	for i in range(selected_cards.size()):
		ids[i] = selected_cards[i].get_id()
	return ids

func update_card_position(card: RenderCard, new_index: int) -> void:
	card.pool_id = new_index
	if new_index >= card_pool.size():
		card_pool.append(card)
	else:
		card_pool[new_index] = card
	card_move_requested.emit(card, new_index)
# 优化后的移动卡片功能
func move_card_to_index(current_pool_id: int, target_index: int, render_event: RenderEvent = RenderEvent.new()) -> void:
	var pool_size: int = card_pool.size()
	current_pool_id = clampi(current_pool_id, 0, pool_size - 1)
	target_index = clampi(target_index, 0, pool_size - 1)
	if current_pool_id == target_index:
		return
	var moved_card: RenderCard = card_pool[current_pool_id]
	var is_forward: bool = current_pool_id < target_index
	var start_index: int
	var end_index: int
	if is_forward:
		start_index = current_pool_id + 1
		end_index = target_index
		for i in range(start_index, end_index + 1):
			update_card_position(card_pool[i], i - 1)
	else:
		start_index = current_pool_id - 1
		end_index = target_index
		for i in range(start_index, end_index - 1, -1):
			# 现在通过update_card_position统一更新位置和card_pool
			update_card_position(card_pool[i], i + 1)
	update_card_position(moved_card, target_index)
	tween_update(render_event)
# 优化后的交换卡片功能
func swap_cards(pool_id_a: int, pool_id_b: int) -> void:
	var pool_size: int = card_pool.size()
	pool_id_a = clampi(pool_id_a, 0, pool_size - 1)
	pool_id_b = clampi(pool_id_b, 0, pool_size - 1)
	if pool_id_a == pool_id_b:
		return
	var card_a = card_pool[pool_id_a]
	var card_b = card_pool[pool_id_b]
	update_card_position(card_a, pool_id_b)
	update_card_position(card_b, pool_id_a)
	render_update()
