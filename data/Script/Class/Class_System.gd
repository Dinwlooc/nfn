extends Node
class_name System

enum GameStage { NULL, START, DRAW }
var game_stages:Dictionary
var game_stage: GameStage = GameStage.NULL
var areaAttack = AreaAttack.new()
var areaDrawing = AreaDrawing.new()
var alive_players:Array[Player]
var current_player_index:int
var cardsmanager = CardManager.new()
signal data_update
	
func _ready() -> void:
	GlobalConsole.register_system(self)
	game_stages = {
	GameStage.START:StageStart.new(),
	GameStage.DRAW:StageDraw.new()
}
	signal_connect_tesy()#调试模式
	load_cards()

func load_cards() -> void:
	areaDrawing.card_pool = cardsmanager.load_all_cards()
	areaDrawing.card_pool.shuffle()

func change_stage(new_stage_name:GameStage) -> void:
	var current_stage:Stage
	if game_stage != GameStage.NULL:
		current_stage = game_stages[game_stage]
	if current_stage:
		current_stage.stage_ended.disconnect(_on_stage_ended)
	if new_stage_name in game_stages:
		game_stage = new_stage_name
		current_stage = game_stages[new_stage_name]	
		current_stage.stage_ended.connect(_on_stage_ended)
		current_stage.enter()
	else:
		push_error("Invalid stage:" + str(new_stage_name))
#####预置功能函数#####
func draw_cards(draw_count:int,players_index:int)-> void:
	var card_pool:Array[Card]
	for i in range(0,draw_count):
		if alive_players.size()&&areaDrawing.card_pool.size():
			card_pool.append(areaDrawing.card_pool.pop_back())
	alive_players[players_index].areaHand.cards_add(card_pool)
	pass

#####信号调用函数#####
func _start_game()-> void:
	if game_stage != GameStage.NULL:
		GlobalConsole._print("Error:c_start未生效。游戏已开始。")
		return
	for i in range(0,GlobalServer.users.size()):
		alive_players.append(Player.new())
		alive_players[i].id = GlobalServer.users[i].id
		GlobalServer.users[i].seat = i
	for i in range(0,alive_players.size()):
		draw_cards(4,i)
	current_player_index = randi_range(0,alive_players.size()-1)
	change_stage(GameStage.START)
	GlobalConsole._print("游戏开始！System Vesion:Beta")
	pass

func _on_stage_ended():
	if game_stage==GameStage.START:
		change_stage(GameStage.DRAW)
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
