## 操作流统一触发器：请求接收、权限管理、响应者设置、操作验证。
extends SystemTrigger
class_name OperationTrigger

var _system: System

func _init(system: System) -> void:
	_system = system
	system.transport.operation_request_received.connect(system.operation_handler.handle_request)
	system.npc_peer_manager.operation_requested.connect(system.operation_handler.handle_request)
	# 改为监听 command_bus 的信号
	system.command_bus.request_set_responsive_players.connect(system.operation_handler.set_responsive_players)
	system.operation_handler.permissions_updated.connect(system.npc_peer_manager.on_permissions_updated)
	system.operation_handler.operation_validated.connect(_on_operation_validated)

func _on_operation_validated(request: OperationRequest) -> void:
	_system.game_state.stage_manager.handle_validated_request(request, _system.game_state, _system.command_bus)
