extends Control
class_name RealCard
#总控卡牌渲染和并处理交互。

var cardface:RealCardFace
var area:RealArea
var move_state:bool = false
var pool_id:int
var selected:bool = false
var dragged:bool = false
var dragging:int = 0
var hovering:bool = false
var path:Dictionary

var data:Dictionary

var type:String = "void"
signal select
signal drag


func _ready()-> void:
	name = "RealCardContorl"
	path = GlobalConfig._resource_registry["cardface"]
	pass
	

func data_update(new_card_data:Dictionary)-> void:
	data = new_card_data
	if !(cardface)||new_card_data["type"] != cardface.type:
		type = new_card_data["type"]
		_load_scene_by_type(type)
	cardface.data_update()
	pass
	

	
func render_update()->RealCard:
	cardface.render_update()
	return self

func _load_scene_by_type(card_type: String) -> void:
	if cardface:
		remove_child(cardface)
		cardface.queue_free()
	cardface = load(path.get(card_type, path["void"])).instantiate()
	add_child(cardface)
	cardface.card = self
	if cardface.has_node("Button"):
		var button = cardface.get_node("Button")
		button.button_down.connect(emit_signal_select)
		button.button_down.connect(emit_signal_dragging)
		button.button_up.connect(emit_signal_dragging)

func emit_signal_select():
	emit_signal("select",pool_id)
	pass
	
func emit_signal_dragging():
	#0为准备就绪，1为长按检测中，2为长按中，3为长按检测失败。
	if dragging == 0:
		dragging = 1
		await get_tree().create_timer(0.1).timeout
		if dragging == 1:
			emit_signal("drag",pool_id)
			dragging = 2
		elif dragging == 3:
			dragging = 0
	elif dragging == 1:
		dragging = 3
	elif dragging == 2:
		emit_signal("drag",pool_id)
		dragging = 0
	pass

func is_hovering(mouse_pos):
	if cardface&&Rect2(position+cardface.position,cardface.size*cardface.scale).has_point(mouse_pos):
		return true
	else:
		return false
