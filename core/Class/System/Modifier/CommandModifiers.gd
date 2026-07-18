## 管理命令修饰器脚本的动态容器，支持添加/移除/重置，并缓存每轮修饰结果
extends RefCounted
class_name CommandModifiers

var _modifiers: Array[Modifier] = []
var _cached_sequence: int = -1
var _cached_results: Array[int] = []  # 存储掩码

func add_modifier(modifier: Modifier) -> void:
	if modifier not in _modifiers:
		_modifiers.append(modifier)

func remove_modifier(modifier: Modifier) -> void:
	_modifiers.erase(modifier)

func get_modifiers() -> Array[Modifier]:
	return _modifiers

## 重置为预设脚本列表（清除所有动态修改并重新加载）
func reset() -> void:
	_modifiers.clear()
	_cached_sequence = -1
	_cached_results.clear()

## 处理修饰器，传入上下文、游戏状态、命令总线、创建者和当前动作序数
func process_modifiers(context: CommandContext, state: GameState, command_bus: CommandBus, creator: Item, sequence: int) -> void:
	if _modifiers.is_empty():
		return
	# 缓存重置检查
	if sequence != _cached_sequence:
		_cached_sequence = sequence
		_cached_results.clear()
		_cached_results.resize(_modifiers.size())
		for i in _cached_results.size():
			_cached_results[i] = 0  # 默认无效果
	# 遍历处理
	for i in _modifiers.size():
		# 若缓存结果包含 LOCK_SELF，则跳过
		if _cached_results[i] & Modifier.LOCK_SELF:
			continue
		var result: int = _modifiers[i].process(context, state, command_bus, creator)
		_cached_results[i] = result
		# 若结果包含 ABORT_TRAVERSAL，中断循环
		if result & Modifier.ABORT_TRAVERSAL:
			break
