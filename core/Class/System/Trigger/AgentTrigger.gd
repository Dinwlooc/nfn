extends SystemTrigger
class_name AgentTrigger

## Agent 管理器引用（由全局注册表取得）
var _agent_manager: AgentManager

## 构造：订阅注册表，AgentManager 就绪后初始化系统层模块并接线到系统层
func _init(system: System) -> void:
	super._init(system)
	GlobalRegistry.connect_singleton(GlobalRegistry.AGENT_MANAGER_TYPE, _on_agent_manager)
## 注册回调：初始化系统层快照构建模块，并部署请求转发与权限中介连接
func _on_agent_manager(instance: Node) -> void:
	if not (instance is AgentManager) or instance == _agent_manager:
		return
	_agent_manager = instance
	_agent_manager.initialize_system(_system.game_state)
	if not _agent_manager.operation_requested.is_connected(_system.operation_handler.handle_request):
		_agent_manager.operation_requested.connect(_system.operation_handler.handle_request)
	if not _system.operation_handler.permissions_updated.is_connected(_agent_manager.on_permissions_updated):
		_system.operation_handler.permissions_updated.connect(
			_agent_manager.on_permissions_updated,
			CONNECT_REFERENCE_COUNTED
		)
## 断开本触发器部署的全部连接
func disconnect_all() -> void:
	if _agent_manager == null or not is_instance_valid(_agent_manager):
		return
	if _agent_manager.operation_requested.is_connected(_system.operation_handler.handle_request):
		_agent_manager.operation_requested.disconnect(_system.operation_handler.handle_request)
	if _system.operation_handler.permissions_updated.is_connected(_agent_manager.on_permissions_updated):
		_system.operation_handler.permissions_updated.disconnect(_agent_manager.on_permissions_updated)
	_agent_manager = null
