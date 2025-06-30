extends Control
class_name RealArea
#总控区域渲染与交互。

var area_name:String
var real_card_pool:Array[RealCard]#储存经过排列的RealCard类
var areaface:RealAreaFace
var choose_list:Array[int]
var choose_limit:int = 1

func _ready():
	areaface = get_child(0)
	areaface.area = self
	ready_expand()
	pass

func ready_expand()->void:
	pass

func render_update()-> void:
	areaface.render_update()
	real_card_pool.map(func(card:RealCard):return card.render_update())
	pass
	
func tween_update()->void:
	if areaface:
		areaface.tween_update()
	pass
	
func cards_add(cards:Array[Dictionary])->void:
	for i in range(0,cards.size()):
			var array_position = real_card_pool.size()
			real_card_pool.append(RealCard.new())
			real_card_pool[array_position].area = self
			real_card_pool[array_position].pool_id = array_position
			real_card_pool[array_position].connect("select",self.on_select)
			real_card_pool[array_position].connect("drag",self.on_drag)
			add_child(real_card_pool[array_position])
			real_card_pool[array_position].data_update(cards[i])
	render_update()
	pass

func on_select(pool_id:int)-> void:
	if real_card_pool[pool_id].selected:
		real_card_pool[pool_id].selected = 0
		choose_list.erase(pool_id)
	else:
		real_card_pool[pool_id].selected = 1
		choose_list.append(pool_id)
	if choose_list.size() > choose_limit:
		real_card_pool[choose_list[0]].selected = 0
		choose_list.remove_at(0)
	GlobalConsole.set_card_on_select(area_name,choose_list)
	areaface.tween_update()
	pass
	
func on_drag(pool_id:int)->void:
	if Input.get_mouse_button_mask()==1:
		GlobalConsole.set_card_on_drag(self,real_card_pool[pool_id])
	else:
		GlobalConsole.remove_card_on_drag()
	pass
