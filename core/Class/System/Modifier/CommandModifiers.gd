## 管理命令修饰器脚本的动态容器，支持添加/移除/重置
extends RefCounted
class_name CommandModifiers

var _modifiers: Array[Modifier] = []

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
