extends Node

# 统一信号定义
signal singleton_registered(type: String, instance: Node)
signal renderarea_registered(name: StringName, area: RenderArea)

# 注册表存储 - 使用字典实现类型解耦
var _singletons: Dictionary = {}
var _renderareas: Dictionary = {}

# 预定义类型常量（避免魔法字符串）
const CONSOLE_TYPE := &"console"
const SYSTEM_TYPE := &"system"
const TIMER_TYPE := &"timer"
const RENDER_CONTROL_TYPE := &"render_control"
const NETWORK_MANAGER_TYPE := &"network_manager"
# 统一注册接口
func register_singleton(type: StringName, instance: Node) -> void:
	check_type(type,instance)
	_singletons[type] = instance
	singleton_registered.emit(type, instance)
func check_type(type:StringName,instance: Object)->void:
	assert(instance != null, "Cannot register null instance")
	match type:
		CONSOLE_TYPE:
			assert(instance is Node, "Console must be a Node")
		SYSTEM_TYPE:
			assert(instance is System, "System must be System type")
		TIMER_TYPE:
			assert(instance is GameTimer, "Timer must be GameTimer type")
		RENDER_CONTROL_TYPE:
			assert(instance is RenderControl, "RenderControl must be RenderControl type")
		NETWORK_MANAGER_TYPE:
			assert(instance is NetworkManager, "NetworkManager must be NetworkManager type")
		_:
			push_warning("Registering unknown singleton type: " + type)
# RenderArea保持独立处理
func register_renderarea(name: StringName, area: RenderArea) -> void:
	assert(area != null, "Cannot register null RenderArea")
	_renderareas[name] = area
	renderarea_registered.emit(name, area)
# 统一的连接接口
func connect_singleton(type: StringName, callback: Callable) -> void:
	if _singletons.has(type):
		callback.call(_singletons[type])
	singleton_registered.connect(func(t: StringName, instance: Node):
		if t == type:
			callback.call(instance))
func connect_renderarea(name: StringName,callback: Callable) -> void:
	if _renderareas.has(name):
		callback.call(_renderareas[name])
	renderarea_registered.connect(func(n: StringName, area: RenderArea):
		if n == name:
			callback.call(area))
