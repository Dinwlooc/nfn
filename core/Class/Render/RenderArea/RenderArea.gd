extends Control
class_name RenderArea
#总控区域渲染与交互。

var area_name:StringName
@export var control:RenderControl
var card_pool:Array[RenderCard]
@export var card_id_to_pool_id: Dictionary[int,int] = {}
var on_select_list:Array[int]
var select_limit:int = 1
var init_child_count:int
signal render_requested(render_event:RenderEvent)
signal tween_requested(render_event:RenderEvent)
signal selected()
signal cards_add_requested(cards:Array[CardPack])
signal cards_added(cards:Array[RenderCard])
signal cards_remove_requested(uids:PackedInt32Array)
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

func on_select(pool_id:int)-> void:
	var card:RenderCard = card_pool[pool_id]
	var card_id:int = -1
	card_id = card.get_id()
	if card.selected:
		card.selected = 0
		on_select_list.erase(card_id)
	else:
		card.selected = 1
		on_select_list.append(card_id)
	if on_select_list.size() > select_limit:
		var removed_card_id = on_select_list[0]
		on_select_list.remove_at(0)
		var removed_pool_id = card_id_to_pool_id.get(removed_card_id)
		if removed_pool_id != null:
			card_pool[removed_pool_id].selected = false
	tween_update()
	selected.emit()
	pass

func on_drag(pool_id:int)->void:
	if !control :
		return
	if Input.get_mouse_button_mask()==1:
		control.set_card_on_drag(self,card_pool[pool_id])
	else:
		control.remove_card_on_drag()
	pass

func get_selected_cards()->Array[RenderCard]:
	var selected:Array[RenderCard] = []
	for card_id in on_select_list:
		var pool_id = card_id_to_pool_id.get(card_id)
		if pool_id != null && pool_id < card_pool.size():
			selected.append(card_pool[pool_id])
	return selected

func update_card_position(card: RenderCard, new_index: int) -> void:
	card.pool_id = new_index
	card_id_to_pool_id[card.get_id()] = new_index
	if card.is_inside_tree():
		move_child(card, new_index + init_child_count)
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
			card_pool[i - 1] = card_pool[i]
			update_card_position(card_pool[i], i - 1)
	else:
		start_index = current_pool_id - 1
		end_index = target_index
		for i in range(start_index, end_index - 1, -1):
			card_pool[i + 1] = card_pool[i]
			update_card_position(card_pool[i], i + 1)
	card_pool[target_index] = moved_card
	update_card_position(moved_card, target_index)
	tween_update(render_event)

# 优化后的交换卡片功能
func swap_cards(pool_id_a: int, pool_id_b: int) -> void:
	var pool_size: int = card_pool.size()
	pool_id_a = clampi(pool_id_a, 0, pool_size - 1)
	pool_id_b = clampi(pool_id_b, 0, pool_size - 1)
	if pool_id_a == pool_id_b:
		return
	var temp = card_pool[pool_id_a]
	card_pool[pool_id_a] = card_pool[pool_id_b]
	card_pool[pool_id_b] = temp
	update_card_position(card_pool[pool_id_a], pool_id_a)
	update_card_position(card_pool[pool_id_b], pool_id_b)
	render_update()
