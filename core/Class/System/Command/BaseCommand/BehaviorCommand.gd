## 行为命令基类
extends RefCounted
class_name BehaviorCommand

var _is_completed: bool = false
var _context: CommandContext

signal companion_command_requested(command: BehaviorCommand)
signal command_completed()

func _init(init_player_id: int = -1,name_overriding:StringName = &"Null" ,context_overriding:CommandContext = CommandContext.new()):
	_context = context_overriding
	_context.command_name = name_overriding
	_context.player_id = init_player_id

func complete() -> void:
	_is_completed = true
	command_completed.emit()
	_context.is_completed = true

func execute(game_state: GameState) -> void:
	complete()

## 追加伴生命令
func append_companion_command(command: BehaviorCommand) -> void:
	companion_command_requested.emit(command)
## 取消命令

func cancel()->void:
	if _context:
		if not _context.can_be_cancelled:
			return
		_context.cancel()
	complete()
