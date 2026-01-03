## 行为命令基类
extends BaseCommand
class_name BehaviorCommand

## 当需要追加伴生命令时发出的信号
signal companion_command_requested(command: BehaviorCommand)
var event_name: StringName
var current_phase: int = 0
var _can_be_cancelled: bool = true
##“取消”使该命令不做后续执行并立即结束。
var is_cancelled: bool = false
##“视为”前缀代表该命令将不执行实际效果，但修饰接口不变。
var is_virtual:bool = false
## 执行命令逻辑（子类必须重写）
func execute(game_state: GameState) -> void:
	complete()
## 追加伴生命令
func append_companion_command(command: BehaviorCommand) -> void:
	companion_command_requested.emit(command)
## 取消命令
func cancel() -> void:
	if _can_be_cancelled:
		is_cancelled = true
## 撤销取消
func uncancel() -> void:
	if _can_be_cancelled:
		is_cancelled = false

func virtualize()->void:
	is_virtual = true
