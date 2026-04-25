extends Node
class_name System

@export var timer: GameTimer
var game_state := GameState.new()
var command_processor := CommandProcessor.new(game_state)
var operation_handler := OperationHandler.new()
var trigger_manager := TriggerManager.new()
var transport: Transport = GlobalTransport
var npc_peer_manager: NPCPeerManager = NPCPeerManager.new(game_state)
var modifier_manager := ModifierManager.new()

func _init() -> void:
	GlobalConstants.register_to(GlobalRegistry)
	game_state.timer = timer
	game_state.player_manager.player_added.connect(_on_player_added)
	game_state.new_behavior_with_callback.connect(_on_new_behavior_with_callback)
	game_state.new_behavior.connect(command_processor.queue_behavior)
	game_state.request_set_responsive_players.connect(operation_handler.set_responsive_players)
	command_processor.enable_processing.connect(_enable_processing)
	command_processor.all_completed.connect(_on_command_processor_all_completed)
	command_processor.command_processing.connect(_on_command_processing)
	npc_peer_manager.operation_requested.connect(operation_handler.handle_request)
	operation_handler.permissions_updated.connect(npc_peer_manager.on_permissions_updated)
	game_state.stage_manager.set_timer(timer)

func _ready() -> void:
	game_state.stage_manager.set_timer(timer)
	transport.operation_request_received.connect(operation_handler.handle_request)
	operation_handler.operation_validated.connect(_on_operation_validated)
	trigger_manager.initialize(self)
	signal_connect_test()
	game_state.load_cards()
	GlobalConsole.c_close.connect(signal_disconnect_test)
	timer.timeout.connect(game_state.stage_manager.on_timer_timeout.bind(game_state))
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

func _on_player_added(player: Player) -> void:
	GlobalConsole._print(["System: 新玩家加入,id:", player.player_id, "，peer_id:", player.peer_id])
	operation_handler.update_verification_mapping(player.peer_id, player.player_id)
	game_state.area_registry.create_areas_for_player(player)

func _on_command_processing(command: BehaviorCommand) -> void:
	modifier_manager.process_modifiers(command._context, game_state)

func _enable_processing(enable: bool) -> void:
	game_state._process_active = enable
	set_process(enable)

func _on_new_behavior_with_callback(command: BehaviorCommand, callback: Callable):
	command_processor.all_completed.connect(callback, CONNECT_ONE_SHOT)
	command_processor.queue_behavior(command)

func _on_command_processor_all_completed() -> void:
	game_state.stage_manager.on_command_processor_idle(game_state)

func _on_operation_validated(request: OperationRequest) -> void:
	game_state.stage_manager.handle_validated_request(request, game_state)

# 调试函数保持不变...
func _start_game() -> void:
	if game_state.stage_manager.get_current_stage_enum() != -1:
		GlobalConsole._print("System:Error:c_start未生效。游戏已开始。")
		return
	var start_event = GameStartCommand.new()
	command_processor.queue_behavior(start_event)
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
	command_processor.queue_behavior(draw_event)
	GlobalConsole._print("System:调试抽卡，（玩家 %s）" % game_state.stage_manager.current_player_id)

func _damage(hp_damage: int = 1, mp_damage: int = 1, player_id: int = 0) -> void:
	command_processor.queue_behavior(DamageCommand.new(game_state.player_manager.get_player_by_id(player_id), hp_damage, mp_damage))

func signal_connect_test():
	GlobalConsole.c_start.connect(_start_game)
	GlobalConsole.c_draw.connect(_draw_cards_test)
	GlobalConsole.c_damage.connect(_damage)
	GlobalConsole._print("System:调试模式已接入系统")

func signal_disconnect_test():
	GlobalConsole.c_start.disconnect(_start_game)
	GlobalConsole.c_draw.disconnect(_draw_cards_test)
	GlobalConsole._print("System:调试模式已断离系统")
