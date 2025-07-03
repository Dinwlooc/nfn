extends Node
class_name System

var all_cards = load("res://mods/offcial/default/Card/Card_load.tres").all_cards as Array
var system = Player.new()
var areaAttack = AreaAttack.new().set_player(system)
var areaDrawing = AreaDrawing.new().set_player(system)
var alive_players:Array[Player]
var current_player_index:int
var game_status:String = "Null"
signal data_update
	

func _ready() -> void:
	GlobalConsole.register_system(self)
	signal_connect_tesy()#调试模式
	load_cards()

func load_cards() -> void:
	for i in range(0,all_cards.size()):
		areaDrawing.card_pool.append(load(all_cards[i]).duplicate().set_suit("Spade") )
		areaDrawing.card_pool.append(load(all_cards[i]).duplicate().set_suit("Heart"))
		areaDrawing.card_pool.append(load(all_cards[i]).duplicate().set_suit("Diamond")) 
		areaDrawing.card_pool.append(load(all_cards[i]).duplicate().set_suit("Club")) 
	areaDrawing.card_pool.shuffle()

func draw_cards(draw_count:int,players_index:int)-> void:
	if game_status != "Null":
		var card_pool:Array[Card]
		for i in range(0,draw_count):
			if alive_players.size()&&areaDrawing.card_pool.size():
				card_pool.append(areaDrawing.card_pool.pop_back())
		alive_players[players_index].areaHand.cards_add(card_pool)
	pass

#####信号调用函数#####
func _start_game()-> void:
	if game_status != "Null":
		GlobalConsole._print("Error:c_start未生效。游戏已开始。")
		return
	game_status = "start"
	for i in range(0,GlobalServer.users.size()):
		alive_players.append(Player.new())
		alive_players[i].id = GlobalServer.users[i].id
		GlobalServer.users[i].seat = i
	for i in range(0,alive_players.size()):
		draw_cards(4,i)
	current_player_index = randi_range(0,alive_players.size()-1)
	start_stage()
	GlobalConsole._print("游戏开始！System Vesion:Beta")
	pass

func start_stage()-> void:
	draw_stage()
	pass	

func draw_stage()->void:
	draw_cards(alive_players[current_player_index].get_NCD_initial(),current_player_index)
	pass

func turn_stage(status:String):
	var statuss = status
	pass
	
	#########仅调试时使用的函数########
	
func _draw_cards_test()->void:
	draw_cards(2,0)
	pass
	
func signal_connect_tesy():
	GlobalConsole.c_start.connect(_start_game)
	GlobalConsole.c_draw.connect(_draw_cards_test)

func signal_disconnect_tesy():
	GlobalConsole.c_start.disconnect(_start_game)
	GlobalConsole.c_draw.disconnect(_draw_cards_test)
