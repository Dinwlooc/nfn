## 容器基类：提供统一的命令处理接口，支持嵌套结构
extends RefCounted
class_name ModifierContainer
## 处理传入的行为命令
func process_command(_command: BehaviorCommand) -> void:
	push_error("process_command not implemented in base ModifierContainer")
