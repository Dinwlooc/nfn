extends Node
class_name System

@export var timer:GameTimer
@export var network_manager:NetworkManager
var game_state := GameState.new()
var modifier_manager := ModifierManager.new(game_state)
var command_processor := CommandProcessor.new(game_state)
var stage_manager := StageManager.new(game_state)
var operation_handler := OperationHandler.new()
var tansport:Transport = GlobalTransport

func _init() -> void:
	GlobalConstants.register_to(GlobalRegistry)
	game_state.timer = timer
	game_state.network_manager = network_manager
	game_state.player_manager.peer_player_added.connect(operation_handler.update_verification_mapping)
	game_state.start_round.connect(stage_manager.start_round)
	game_state.new_behavior_with_callback.connect(_on_new_behavior_with_callback)
	game_state.set_responsive_players.connect(operation_handler.set_responsive_players)
	command_processor.command_processing.connect(modifier_manager.process_behavior)
	command_processor.enable_processing.connect(_enable_processing)

func _ready() -> void:
	stage_manager.set_timer(timer)
	tansport.operation_request_received.connect(operation_handler.handle_request)
	operation_handler.operation_validated.connect(stage_manager.handle_validated_request)
	signal_connect_test()
	game_state.load_cards()
	GlobalConsole.c_close.connect(signal_disconnect_test)

## 处理阶段切换事件
func _process(_delta: float) -> void:
	if game_state._process_active:
		command_processor.process()
	else:
		set_process(false)

func _enable_processing(enable: bool) -> void:
	game_state._process_active = enable
	set_process(enable)

func _on_new_behavior_with_callback(command:BehaviorCommand,callback:Callable):
	command_processor.all_completed.connect(callback,CONNECT_ONE_SHOT)
	command_processor.queue_behavior(command)
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
	if game_state._process_active:
		GlobalConsole._print("System:Error:c_draw未生效。无法插入事件至处理中的堆栈。")
		return
	if stage_manager.get_current_stage_enum() == -1:
		GlobalConsole._print("System:Error:c_draw未生效。游戏未开始。")
		return
	if game_state.player_manager.players.is_empty():
		GlobalConsole._print("System:Error:c_draw未生效。无存活玩家。")
		return
	var draw_event = DrawCardsCommand.new(
		game_state.current_player_index,
		2  # 默认抽卡数量
		)
	command_processor.queue_behavior(draw_event)
	GlobalConsole._print("System:调试抽卡，（玩家 %s）" % game_state.current_player_index)

func signal_connect_test():
	GlobalConsole.c_start.connect(_start_game)
	GlobalConsole.c_draw.connect(_draw_cards_test)
	GlobalConsole._print("System:调试模式已接入系统")

func signal_disconnect_test():
	GlobalConsole.c_start.disconnect(_start_game)
	GlobalConsole.c_draw.disconnect(_draw_cards_test)
	GlobalConsole._print("System:调试模式已断离系统")
