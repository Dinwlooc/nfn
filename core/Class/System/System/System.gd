extends Node
class_name System

@export var timer: GameTimer
var game_state := GameState.new()
var command_processor := CommandProcessor.new(game_state)
var command_bus := CommandBus.new(game_state)
var operation_handler := OperationHandler.new()
var trigger_manager := TriggerManager.new()
var transport: Transport = GlobalTransport
var npc_peer_manager: NPCPeerManager = NPCPeerManager.new(game_state)
var modifier_manager := ModifierManager.new()

func _init() -> void:
	GlobalConstants.register_to(GlobalRegistry)
	game_state.timer = timer
	game_state.stage_manager.set_timer(timer)

func _ready() -> void:
	game_state.stage_manager.set_timer(timer)
	trigger_manager.initialize(self)
	signal_connect_test()
	game_state.load_cards()
	GlobalConsole.c_close.connect(signal_disconnect_test)
	call_deferred(&"start_server")

func start_server() -> void:
	transport.start_server()
	game_state.users = transport.network_manager.users

func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 4 != 0:
		return
	if not game_state._process_active:
		return
	command_processor.process()

func _start_game() -> void:
	if game_state.stage_manager.get_current_stage_enum() != -1:
		GlobalConsole._print("System:Error:c_start未生效。游戏已开始。")
		return
	var start_event = GameStartCommand.new(command_bus)
	command_bus.queue_behavior(start_event)
	GlobalConsole._print("System:游戏开始事件已创建")

func _draw_cards_test() -> void:
	if game_state._process_active:
		GlobalConsole._print("System:Error:c_draw未生效。无法插入事件至处理中的堆栈。")
		return
	if game_state.stage_manager.get_current_stage_enum() == -1:
		GlobalConsole._print("System:Error:c_draw未生效。游戏未开始。")
		return
	if game_state.player_manager.players.is_empty():
		GlobalConsole._print("System:Error:c_draw未生效。无存活玩家。")
		return
	var draw_event = DrawCardsCommand.new(
		game_state.stage_manager.current_player_id,
		2
	)
	command_bus.queue_behavior(draw_event)
	GlobalConsole._print("System:调试抽卡，（玩家 %s）" % game_state.stage_manager.current_player_id)

func _damage(hp_damage: int = 1, mp_damage: int = 1, player_id: int = 2) -> void:
	command_bus.queue_behavior(DamageCommand.new(game_state.player_manager.get_player_by_id(player_id), hp_damage, mp_damage))

func signal_connect_test():
	GlobalConsole.c_start.connect(_start_game)
	GlobalConsole.c_draw.connect(_draw_cards_test)
	GlobalConsole.c_damage.connect(_damage)
	GlobalConsole._print("System:调试模式已接入系统")

func signal_disconnect_test():
	GlobalConsole.c_start.disconnect(_start_game)
	GlobalConsole.c_draw.disconnect(_draw_cards_test)
	GlobalConsole._print("System:调试模式已断离系统")
