extends Node
class_name System

enum GameStage { NULL, START, DRAW , MAIN , DISCARD , END}
var game_stages:Dictionary[GameStage, Stage]
var game_stage: GameStage = GameStage.NULL
var area_attack = AreaAttack.new()
var area_drawing = AreaDrawing.new()
var alive_players:Array[Player]
var current_player_index:int
var cardsmanager = CardManager.new()
var event_processor = EventProcessor.new(self)
var _process_active := false
@export var timer:GameTimer
@export var network_manager:NetworkManager
signal data_update

func _ready() -> void:
	signal_connect_test()#调试模式
	load_cards()
	GlobalConsole.c_close.connect(signal_disconnect_test)

func _process(delta: float) -> void:
	if _process_active:
		event_processor.process_events()

func load_cards() -> void:
	area_drawing.card_pool = cardsmanager.load_all_cards()
	area_drawing.card_pool.shuffle()
	
func enable_processing(enable: bool) -> void:
	_process_active = enable
	set_process(enable)

func change_stage(new_stage: GameStage) -> void:
	var event = StageTransitionEvent.new(new_stage)
	event_processor.queue_behavior(event)

func stage_ended():
	if game_stage == GameStage.START:
		change_stage(GameStage.DRAW)
	pass
#####信号调用函数#####
func _start_game()-> void:
	const INIT_CARDS_COUNT:int = 4
	if game_stage != GameStage.NULL:
		GlobalConsole._print("System:Error:c_start未生效。游戏已开始。")
		return
	game_stages = {
	GameStage.START:StageStart.new(self,timer),
	GameStage.DRAW:StageDraw.new(self,timer),
	GameStage.MAIN:StageMain.new(self,timer),
	GameStage.END:StageEnd.new(self,timer)
	}
	if network_manager:
		for i in range(0,network_manager.users.size()):
			alive_players.append(Player.new().set_id(network_manager.users[i].id))
			network_manager.users[i].seat = i
	else:
		alive_players.append(Player.new().set_id(1))
	for players_index in range(0,alive_players.size()):
		var card_pool:Array[Card]
		for i in range(0,INIT_CARDS_COUNT):
			if alive_players.size()&&area_drawing.card_pool.size():
				card_pool.append(area_drawing.card_pool.pop_back())
		alive_players[players_index].area_hand.cards_add(card_pool)
	current_player_index = randi_range(0,alive_players.size()-1)
	change_stage(GameStage.START)
	GlobalConsole._print("System:游戏开始！System Vesion:Beta")
	#########仅调试时使用的函数########
func _draw_cards_test() -> void:
	if _process_active:
		GlobalConsole._print("System:Error:c_draw未生效。无法插入事件至处理中的堆栈。")
		return
	if game_stage == GameStage.NULL:
		GlobalConsole._print("System:Error:c_draw未生效。游戏未开始。")
		return
	if alive_players.is_empty():
		GlobalConsole._print("System:Error:c_draw未生效。无存活玩家。")
		return
	var draw_event = DrawCardsEvent.new(
		current_player_index,
		2  # 默认抽卡数量
		)
	event_processor.queue_behavior(draw_event)
	GlobalConsole._print("System:调试抽卡，（玩家 %s）" % current_player_index)
	
func signal_connect_test():
	GlobalConsole.c_start.connect(_start_game)
	GlobalConsole.c_draw.connect(_draw_cards_test)
	GlobalConsole._print("System:调试模式已接入系统")

func signal_disconnect_test():
	GlobalConsole.c_start.disconnect(_start_game)
	GlobalConsole.c_draw.disconnect(_draw_cards_test)
	GlobalConsole._print("System:调试模式已断离系统")
