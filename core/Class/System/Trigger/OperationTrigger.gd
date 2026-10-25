extends SystemTrigger
class_name OperationTrigger

## 构造：接管系统并连接操作请求信号
func _init(system: System) -> void:
	super._init(system)
	_system.transport.operation_request_received.connect(_system.operation_handler.handle_request)
	_system.command_bus.request_set_responsive_players.connect(_system.operation_handler.set_responsive_players)
	_system.operation_handler.operation_validated.connect(_on_operation_validated)
	_system.game_state.player_manager.player_added.connect(_on_player_added)
## @signal_listener 玩家添加时更新映射
func _on_player_added(player: Player) -> void:
	_system.operation_handler.update_verification_mapping(player.peer_id, player.get_id())
## @signal_listener 操作验证通过后交由阶段管理器处理
func _on_operation_validated(request: OperationRequest) -> void:
	_system.game_state.stage_manager.handle_validated_request(request, _system.game_state, _system.command_bus)
##
func disconnect_all() -> void:
	_system.transport.operation_request_received.disconnect(_system.operation_handler.handle_request)
	_system.command_bus.request_set_responsive_players.disconnect(_system.operation_handler.set_responsive_players)
	_system.operation_handler.operation_validated.disconnect(_on_operation_validated)
	_system.game_state.player_manager.player_added.disconnect(_on_player_added)
