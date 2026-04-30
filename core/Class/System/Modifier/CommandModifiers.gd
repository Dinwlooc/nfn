## 管理命令修饰器脚本的动态容器，支持添加/移除/重置
extends RefCounted
class_name CommandModifiers

var _modifiers: Array[Script] = []

func add_modifier(script: Script) -> void:
	if script not in _modifiers:
		_modifiers.append(script)

func remove_modifier(script: Script) -> void:
	_modifiers.erase(script)

func get_modifiers() -> Array[Script]:
	return _modifiers.duplicate()

## 重置为预设脚本列表（清除所有动态修改并重新加载）
func reset(preset: Array[Script]) -> void:
	_modifiers.clear()
	for script in preset:
		_modifiers.append(script)
