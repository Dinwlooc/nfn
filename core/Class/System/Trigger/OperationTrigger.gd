## 操作流统一触发器：请求接收、权限管理、响应者设置、操作验证。
## 同时负责维护 peer_id → player_id 映射。
extends SystemTrigger
class_name OperationTrigger

var _system: System

func _init(system: System) -> void:
	_system = system
	# 原有连接
	system.transport.operation_request_received.connect(system.operation_handler.handle_request)
	system.npc_peer_manager.operation_requested.connect(system.operation_handler.handle_request)
	system.command_bus.request_set_responsive_players.connect(system.operation_handler.set_responsive_players)
	system.operation_handler.permissions_updated.connect(system.npc_peer_manager.on_permissions_updated)
	system.operation_handler.operation_validated.connect(_on_operation_validated)
	system.game_state.player_manager.player_added.connect(_on_player_added)

func _on_player_added(player: Player) -> void:
	# 将原本属于 PlayerTrigger 的映射逻辑移到这里
	_system.operation_handler.update_verification_mapping(player.peer_id, player.get_id())

func _on_operation_validated(request: OperationRequest) -> void:
	_system.game_state.stage_manager.handle_validated_request(request, _system.game_state, _system.command_bus)
