extends Control
class_name RenderArea
#总控区域渲染与交互。

var area_name:String
@export var card_pool:Array[RenderCard]
@export var card_id_to_pool_id: Dictionary[int,int] = {}
var on_select_list:Array[int]
var select_limit:int = 1
var init_child_count:int
signal render_requested(render_event:RenderEvent)
signal tween_requested(render_event:RenderEvent)
signal selected

func _ready():
	init_child_count = get_child_count()
	ready_expand()
	pass

func ready_expand()->void:
	pass

func render_update(render_event:RenderEvent = RenderEvent.new())-> void:
	emit_signal("render_requested",render_event)
	pass
	
func tween_update(render_event:RenderEvent = RenderEvent.new())->void:
	emit_signal("tween_requested",render_event)
	pass
	
func cards_add(cards:Array[Dictionary])->void:
	for i in range(0,cards.size()):
			var array_position = card_pool.size()
			var new_card:RenderCard = RenderCard.new()
			new_card.area = self
			new_card.pool_id = array_position
			card_pool.append(new_card)
			add_child(new_card)
			new_card.data_update(cards[i])
			card_id_to_pool_id[ cards[i]["id"] ] = array_position

	render_update()
	pass

func on_select(pool_id:int)-> void:
	var card:RenderCard = card_pool[pool_id]
	var card_id:int = -1
	if card.data.has("id"):
		card_id = card.data["id"]
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
	if Input.get_mouse_button_mask()==1:
		GlobalConsole.set_card_on_drag(self,card_pool[pool_id])
	else:
		GlobalConsole.remove_card_on_drag()
	pass

func get_selected_cards()->Array[RenderCard]:
	var selected:Array[RenderCard] = []
	for card_id in on_select_list:
		var pool_id = card_id_to_pool_id.get(card_id)
		if pool_id != null && pool_id < card_pool.size():
			selected.append(card_pool[pool_id])
			print(selected)
	return selected

func swap_cards(pool_id_a:int, pool_id_b:int)->void:
	# 交换卡牌位置
	var temp = card_pool[pool_id_a]
	card_pool[pool_id_a] = card_pool[pool_id_b]
	card_pool[pool_id_b] = temp
	# 更新pool_id引用
	card_pool[pool_id_a].pool_id = pool_id_a
	card_pool[pool_id_b].pool_id = pool_id_b
	# 更新映射
	card_id_to_pool_id[card_pool[pool_id_a].data["id"]] = pool_id_a
	card_id_to_pool_id[card_pool[pool_id_b].data["id"]] = pool_id_b
	move_child(card_pool[pool_id_a], pool_id_a+init_child_count)
	move_child(card_pool[pool_id_b], pool_id_b+init_child_count)
	render_update()

func move_card_to_index(current_pool_id: int, target_index: int , expend_render_property:Dictionary={}) -> void:
	# 边界检查
	if current_pool_id < 0 || current_pool_id >= card_pool.size():
		push_error("Invalid current_pool_id: " + str(current_pool_id))
		return
	if target_index < 0 || target_index >= card_pool.size():
		push_error("Invalid target_index: " + str(target_index))
		return
	if current_pool_id == target_index:
		return  # 无需移动
	var moved_card:RenderCard= card_pool[current_pool_id]
	# 临时存储移动范围内的卡牌
	var affected_cards := []
	if current_pool_id < target_index:
		# 向右移动：从右向左处理
		for i in range(target_index, current_pool_id, -1):
			affected_cards.append(card_pool[i])
	else:
		# 向左移动：从右向左处理
		for i in range(current_pool_id - 1, target_index - 1, -1):
			affected_cards.append(card_pool[i])
	# 批量更新索引 
	for idx in affected_cards.size():
		var card := affected_cards[idx] as RenderCard
		var new_id = card.pool_id - 1 if current_pool_id < target_index else card.pool_id + 1
		card_pool[new_id] = card
		card.pool_id = new_id
		card_id_to_pool_id[card.data["id"]] = new_id
	card_pool[target_index] = moved_card
	moved_card.pool_id = target_index
	card_id_to_pool_id[moved_card.data["id"]] = target_index
	for i in range(min(target_index, current_pool_id), max(target_index, current_pool_id) + 1):
		move_child(card_pool[i], i + init_child_count)
	render_update(RenderEvent.new().set_config(expend_render_property))
