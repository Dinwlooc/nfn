## 全局配置表
## 该单例尚未投入使用。
extends Node
# 统一信号定义
## 单例注册完成（类型键 + 实例）
## @emitter
signal singleton_registered(type: String, instance: Node)
## 常量表注册完成
## @emitter
signal constant_registered(type: StringName)  # 新增常量注册信号

# 注册表存储
## 单例表：类型键 → 实例
var _singletons: Dictionary = {}
## 常量表：类型键 → { &"array": Array[StringName], &"dic": Dictionary }
var _constants: Dictionary = {}  # 新增常量存储 { type: { array: [], dic: {} } }

# 预定义类型常量
## 控制台单例类型键
const CONSOLE_TYPE := &"console"
## 系统单例类型键
const SYSTEM_TYPE := &"system"
## 计时器单例类型键
const TIMER_TYPE := &"timer"
## 渲染控制单例类型键
const RENDER_CONTROL_TYPE := &"render_control"
## 网络管理器单例类型键
const NETWORK_MANAGER_TYPE := &"network_manager"
# 新增常量注册接口
## 注册一组常量名，建立 名↔序 双向映射（断言名称数与枚举长度一致）
## @side_effect @emitter
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
## 按序号取常量名（未注册或越界断言失败）
func get_constant_name(type: StringName, index: int) -> StringName:
	assert(_constants.has(type), "Constant type not registered: " + type)
	var arr: Array = _constants[type][&"array"]
	assert(index >= 0 and index < arr.size(), "Index out of range for constant " + type)
	return arr[index]

## 按常量名取序号（未注册或未知名断言失败）
func get_constant_index(type: StringName, _name: StringName) -> int:
	assert(_constants.has(type), "Constant type not registered: " + type)
	var dict: Dictionary = _constants[type][&"dic"]
	assert(dict.has(_name), "Name %s not found in constant %s" % [_name, type])
	return dict[_name]

## 注册单例，并按类型键做类型校验
## @side_effect @emitter
func register_singleton(type: StringName, instance: Node) -> void:
	check_type(type, instance)
	_singletons[type] = instance
	singleton_registered.emit(type, instance)

## 按类型键断言实例类型；未知类型仅告警
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

## 订阅某类型单例：已注册立即回调，未注册则等注册完成后回调
## @side_effect
func connect_singleton(type: StringName, callback: Callable) -> void:
	if _singletons.has(type):
		callback.call(_singletons[type])
	singleton_registered.connect(func(t: StringName, instance: Node):
		if t == type:
			callback.call(instance))

## 取已注册单例（未注册断言失败）
func get_singleton(type: StringName) -> Node:
	assert(_singletons.has(type), "Singleton not registered: " + type)
	return _singletons[type]
