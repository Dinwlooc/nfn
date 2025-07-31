extends Control
class_name RenderArea
#总控区域渲染与交互。

var area_name:String
var card_pool:Array[RenderCard]
var choose_list:Array[int]
var choose_limit:int = 1
signal render_requested()
signal tween_requested()

func _ready():
	ready_expand()
	pass

func ready_expand()->void:
	pass

func render_update()-> void:
	emit_signal("render_requested")
	#card_pool.map(func(card:RenderCard):return card.render_update())
	pass
	
func tween_update()->void:
	emit_signal("tween_requested")
	pass
	
func cards_add(cards:Array[Dictionary])->void:
	for i in range(0,cards.size()):
			var array_position = card_pool.size()
			card_pool.append(RenderCard.new())
			card_pool[array_position].area = self
			card_pool[array_position].pool_id = array_position
			card_pool[array_position].connect("select",self.on_select)
			card_pool[array_position].connect("drag",self.on_drag)
			add_child(card_pool[array_position])
			card_pool[array_position].data_update(cards[i])
	render_update()
	pass

func on_select(pool_id:int)-> void:
	if card_pool[pool_id].selected:
		card_pool[pool_id].selected = 0
		choose_list.erase(pool_id)
	else:
		card_pool[pool_id].selected = 1
		choose_list.append(pool_id)
	if choose_list.size() > choose_limit:
		card_pool[choose_list[0]].selected = 0
		choose_list.remove_at(0)
	GlobalConsole.set_card_on_select(area_name,choose_list)
	tween_update()
	pass
	
func on_drag(pool_id:int)->void:
	if Input.get_mouse_button_mask()==1:
		GlobalConsole.set_card_on_drag(self,card_pool[pool_id])
	else:
		GlobalConsole.remove_card_on_drag()
	pass
