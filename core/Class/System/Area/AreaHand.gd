extends Area
class_name AreaHand

func _init_expand()->void:
	area_name = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.HAND]

func play()->void:
	if card_pool[0]:
		var settlement_cost = card_pool[0].play_cost()
		print("消耗：",settlement_cost)
	pass
	#打出手牌的方法。
func user_signal()-> void:
	pass
