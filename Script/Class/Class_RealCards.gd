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

var basic_cost:int
var basic_damage:int
var description:String
var real_name:String
var suit:String
var texture_path:String

var type:String = "void"
const path = {
	"void": "res://tscn/real_card/voidcard.tscn",
	"attack": "res://tscn/real_card/attackcard.tscn",
	# 内置卡牌类型。
}
signal select
signal drag


func _ready()-> void:
	name = "RealCardContorl"
	pass
	

func data_update(new_card_data:Dictionary)-> void:
	texture_path = get_texture_path(new_card_data["name"],new_card_data["type"])
	basic_cost = new_card_data["basic_cost"]
	basic_damage = new_card_data["basic_damage"]
	description = new_card_data["description"]
	real_name = new_card_data["real_name"]
	suit = new_card_data["suit"]
	if !(cardface)||new_card_data["type"] != cardface.type:
		type = new_card_data["type"]
		_load_scene_by_type(type)
	cardface.data_update()
	pass
	
func get_texture_path(card_name:String,card_type:String) -> String:
	# 分割命名空间和卡牌名
	var name_parts := card_name.split(":")
	var name_space = "default"
	var card_key = card_name
	if name_parts.size() >= 2:
		name_space = name_parts[0]
		card_key = name_parts[1]
	elif name_parts.size() == 1:
		card_key = name_parts[0]
	# 构建贴图路径
	return "res://Picture/%s/Cards/%s/%s.png" % [name_space, card_type, card_key]
	
	
func render_update()->RealCard:
	cardface.render_update()
	return self

func _load_scene_by_type(card_type: String) -> void:
	if cardface:
		remove_child(cardface)
		cardface.queue_free()
	var type_to_path = path["void"]
	if path[card_type]:
		type_to_path = path[card_type]
	cardface = load(type_to_path).instantiate()
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
