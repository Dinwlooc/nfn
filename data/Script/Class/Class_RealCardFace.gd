extends Control
class_name RealCardFace
#卡面渲染的基类

var card:RealCard

func _ready():
	pass
	
func render_update()->void:
	pass
	
func get_suit(suit:String) ->int:
	if suit == "Heart":
		return 0
	if suit == "Diamond":
		return 1
	if suit == "Spade":
		return 2
	if suit == "Club":
		return 3
	return 0


