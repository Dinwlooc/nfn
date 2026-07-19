## 管理命令修饰器脚本的动态容器，支持添加/移除/重置，并缓存每轮修饰结果
extends RefCounted
class_name CommandModifiers

var _modifiers: Array[Modifier] = []
var _cached_sequence: int = -1
var _cached_results: Array[ModifierContext] = []

func add_modifier(modifier: Modifier) -> void:
	if modifier not in _modifiers:
		_modifiers.append(modifier)

func remove_modifier(modifier: Modifier) -> void:
	_modifiers.erase(modifier)

func get_modifiers() -> Array[Modifier]:
	return _modifiers

func reset() -> void:
	_modifiers.clear()
	_cached_sequence = -1
	_cached_results.clear()

## 处理修饰器，传入上下文、游戏状态、命令总线、创建者和当前动作序数
func process_modifiers(context: CommandContext, state: GameState, command_bus: CommandBus, creator: Item, sequence: int) -> void:
	if _modifiers.is_empty():
		return
	if sequence != _cached_sequence:
		_cached_sequence = sequence
		_cached_results.clear()
		_cached_results.resize(_modifiers.size())
		for i in _cached_results.size():
			_cached_results[i] = ModifierContext.new()
	for i in _modifiers.size():
		var input_ctx := ModifierContext.new()
		var result: ModifierContext = _modifiers[i].process(context, state, input_ctx, creator)
		_cached_results[i] = result
		# 发送待处理命令并清空
		var cmds:Array[BehaviorCommand] = result.take_commands()
		for cmd in cmds:
			command_bus.queue_behavior(cmd)
