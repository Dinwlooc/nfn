## 行为命令基类
extends BaseCommand
class_name BehaviorCommand

## 当需要追加伴生命令时发出的信号
signal companion_command_requested(command: BehaviorCommand)
var event_name: StringName
var current_phase: int = 0
var _can_be_cancelled: bool = true
var is_cancelled: bool = false
## 执行命令逻辑（子类必须重写）
func execute(system: System) -> void:
	complete()
## 追加伴生命令
func append_companion_command(command: BehaviorCommand) -> void:
	companion_command_requested.emit(command)
## 完成命令
func complete(options: Dictionary = {}) -> void:
	is_completed = true
## 取消命令
func cancel() -> void:
	if _can_be_cancelled:
		is_cancelled = true
## 撤销取消
func uncancel() -> void:
	if _can_be_cancelled:
		is_cancelled = false
