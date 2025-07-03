extends RefCounted
class_name Area

var card_pool:Array[Card] = []
#区域卡池。存放卡牌（Card类）。
var player:Player
var area_name:String

signal area_cards_add

func cards_add(new_cardpool:Array[Card]):
	card_pool.append_array(new_cardpool)
	var data = GlobalServer.cards_rpc(self,"cards_add",new_cardpool)
	pass

func set_player(new_player:Player):
	player = new_player
	return self


	
