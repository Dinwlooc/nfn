extends Node
class_name System

enum GameStage { START, DRAW , MAIN , DISCARD , END}
@export var timer:GameTimer
@export var network_manager:NetworkManager
var area_center := AreaCenter.new()
var area_drawing := AreaDrawing.new()
var current_player_index:int
var cardsmanager := CardsManager.new()
var player_manager := PlayersManager.new()
var modifier_manager := ModifierManager.new(self)
var command_processor := CommandProcessor.new(self)
var stage_manager := StageManager.new(self)
var operation_handler := OperationRequestHandler.new()
var _process_active := false
signal data_update

func _init() -> void:
	GlobalConstants.register_to(GlobalRegistry)
	player_manager.peer_player_added.connect(
		operation_handler.update_verification_mapping
	)
	command_processor.command_processing.connect(modifier_manager.process_behavior)

func _ready() -> void:
	stage_manager.set_timer(timer)
	stage_manager.permissions_update_requested.connect(_handle_permissions_update)
	signal_connect_test()#调试模式
	load_cards()
	GlobalConsole.c_close.connect(signal_disconnect_test)

func _process(_delta: float) -> void:
	if _process_active:
		command_processor.process()

func load_cards() -> void:
	area_drawing.cards_add(cardsmanager.load_all_cards())
	area_drawing.shuffle_card_pool()

func enable_processing(enable: bool) -> void:
	_process_active = enable
	set_process(enable)

func _handle_permissions_update(player_id: int, permissions: Array[StringName]) -> void:
	operation_handler.set_player_permissions(player_id, permissions.duplicate())
	var blacklist: Array[StringName] = player_manager.get_operation_disallowed(player_id)
	if not blacklist.is_empty():
		operation_handler.apply_player_blacklist(player_id, blacklist)
#####信号调用函数#####
func _start_game()-> void:
	if stage_manager.get_current_stage_enum() != -1:
		GlobalConsole._print("System:Error:c_start未生效。游戏已开始。")
		return
	var start_event = GameStartCommand.new()
	command_processor.queue_behavior(start_event)
	GlobalConsole._print("System:游戏开始事件已创建")
	#########仅调试时使用的函数########
func _draw_cards_test() -> void:
	if _process_active:
		GlobalConsole._print("System:Error:c_draw未生效。无法插入事件至处理中的堆栈。")
		return
	if stage_manager.get_current_stage_enum() == -1:
		GlobalConsole._print("System:Error:c_draw未生效。游戏未开始。")
		return
	if player_manager.players.is_empty():
		GlobalConsole._print("System:Error:c_draw未生效。无存活玩家。")
		return
	var draw_event = DrawCardsCommand.new(
		current_player_index,
		2  # 默认抽卡数量
		)
	command_processor.queue_behavior(draw_event)
	GlobalConsole._print("System:调试抽卡，（玩家 %s）" % current_player_index)

func signal_connect_test():
	GlobalConsole.c_start.connect(_start_game)
	GlobalConsole.c_draw.connect(_draw_cards_test)
	GlobalConsole._print("System:调试模式已接入系统")

func signal_disconnect_test():
	GlobalConsole.c_start.disconnect(_start_game)
	GlobalConsole.c_draw.disconnect(_draw_cards_test)
	GlobalConsole._print("System:调试模式已断离系统")
