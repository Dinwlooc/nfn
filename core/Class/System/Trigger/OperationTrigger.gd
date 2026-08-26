extends SystemTrigger
class_name OperationTrigger

func _init(system: System) -> void:
	super._init(system)
	_system.transport.operation_request_received.connect(_system.operation_handler.handle_request)
	_system.npc_peer_manager.operation_requested.connect(_system.operation_handler.handle_request)
	_system.command_bus.request_set_responsive_players.connect(_system.operation_handler.set_responsive_players)
	_system.operation_handler.operation_validated.connect(_on_operation_validated)
	_system.game_state.player_manager.player_added.connect(_on_player_added)
	_setup_mediator_connections()
## @signal-mediator 部署中介连接：permissions_updated → npc_peer_manager
func _setup_mediator_connections() -> void:
	_system.operation_handler.permissions_updated.connect(
		_system.npc_peer_manager.on_permissions_updated,
		CONNECT_REFERENCE_COUNTED
	)
## @signal-listener 玩家添加时更新映射
func _on_player_added(player: Player) -> void:
	_system.operation_handler.update_verification_mapping(player.peer_id, player.get_id())
## @signal-listener 操作验证通过后交由阶段管理器处理
func _on_operation_validated(request: OperationRequest) -> void:
	_system.game_state.stage_manager.handle_validated_request(request, _system.game_state, _system.command_bus)
##
func disconnect_all() -> void:
	_system.transport.operation_request_received.disconnect(_system.operation_handler.handle_request)
	_system.npc_peer_manager.operation_requested.disconnect(_system.operation_handler.handle_request)
	_system.command_bus.request_set_responsive_players.disconnect(_system.operation_handler.set_responsive_players)
	_system.operation_handler.operation_validated.disconnect(_on_operation_validated)
	_system.game_state.player_manager.player_added.disconnect(_on_player_added)
	_system.operation_handler.permissions_updated.disconnect(_system.npc_peer_manager.on_permissions_updated)
