extends Node

# 统一信号定义
signal singleton_registered(type: String, instance: Node)
signal renderarea_registered(name: StringName, area: RenderArea)
signal constant_registered(type: StringName)  # 新增常量注册信号

# 注册表存储
var _singletons: Dictionary = {}
var _renderareas: Dictionary = {}
var _constants: Dictionary = {}  # 新增常量存储 { type: { array: [], dic: {} } }

# 预定义类型常量
const CONSOLE_TYPE := &"console"
const SYSTEM_TYPE := &"system"
const TIMER_TYPE := &"timer"
const RENDER_CONTROL_TYPE := &"render_control"
const NETWORK_MANAGER_TYPE := &"network_manager"
# 新增常量注册接口
func register_constant(type: StringName, names: Array[StringName], enum_size: int) -> void:
	assert(names.size() == enum_size, 
		"Constant size mismatch for %s: expected %d got %d" % [type, enum_size, names.size()])
	# 创建双向映射
	var array_map := names.duplicate()
	var dict_map := {}
	for i in names.size():
		dict_map[names[i]] = i
	_constants[type] = {
		&"array": array_map,
		&"dic": dict_map
	}
	constant_registered.emit(type)
# 常量查询接口
func get_constant_name(type: StringName, index: int) -> StringName:
	assert(_constants.has(type), "Constant type not registered: " + type)
	var arr: Array = _constants[type][&"array"]
	assert(index >= 0 and index < arr.size(), "Index out of range for constant " + type)
	return arr[index]

func get_constant_index(type: StringName, _name: StringName) -> int:
	assert(_constants.has(type), "Constant type not registered: " + type)
	var dict: Dictionary = _constants[type][&"dic"]
	assert(dict.has(_name), "Name %s not found in constant %s" % [_name, type])
	return dict[_name]

func register_singleton(type: StringName, instance: Node) -> void:
	check_type(type, instance)
	_singletons[type] = instance
	singleton_registered.emit(type, instance)

func check_type(type: StringName, instance: Object) -> void:
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

func register_renderarea(_name: StringName, area: RenderArea) -> void:
	assert(area != null, "Cannot register null RenderArea")
	_renderareas[_name] = area
	renderarea_registered.emit(_name, area)

func connect_singleton(type: StringName, callback: Callable) -> void:
	if _singletons.has(type):
		callback.call(_singletons[type])
	singleton_registered.connect(func(t: StringName, instance: Node):
		if t == type:
			callback.call(instance))

func connect_renderarea(_name: StringName, callback: Callable) -> void:
	if _renderareas.has(_name):
		callback.call(_renderareas[_name])
	renderarea_registered.connect(func(n: StringName, area: RenderArea):
		if n == _name:
			callback.call(area))

func get_singleton(type: StringName) -> Node:
	assert(_singletons.has(type), "Singleton not registered: " + type)
	return _singletons[type]

func get_renderarea(_name: StringName) -> RenderArea:
	assert(_renderareas.has(_name), "RenderArea not registered: " + _name)
	return _renderareas[_name]
