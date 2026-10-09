## 行为命令基类
## 很多下级命令基类会预设execute结构、传输行为和样板方法。在重写位于execute的业务方法时，请注意需要显式切换状态机。
## 虚拟化时，命令只执行纯函数。当纯函数用于向context缓存数值、依赖时，需在虚拟化的断点前执行。
## 非持久化地获取、检查依赖以辅助业务执行的纯函数，则在虚拟化时也不执行。
@abstract
extends RefCounted
class_name BehaviorCommand

var _is_completed: bool = false
var _context: CommandContext

## @requester
signal companion_command_requested(command: BehaviorCommand)
## @emitter
signal command_completed()

# ## 子类需要定义该内部类。
# ## @context @deep_inherit
# class Context

## @facade
@abstract func execute(game_state: GameState) -> void
## @internal @seam_override
func _init(init_player_id: int = 1 ,name_overriding:StringName = &"" ,context_overriding:CommandContext = CommandContext.NULL_CONTEXT):
	_context = context_overriding
	_context.command_name = name_overriding
	_context.player_id = init_player_id
## 完成命令，调用上下文的 complete()
## @internal @emitter
func complete() -> void:
	_is_completed = true
	_context.complete()
	command_completed.emit()
## 伴生一个命令
## @facade @seam @external @requester
func append_companion_command(command: BehaviorCommand,companion_source_overriding:CommandContext = _context) -> void:
	if command._context:
		command._context.set_companion_source(companion_source_overriding)
	companion_command_requested.emit(command)
## 取消命令
## @facade @internal
func cancel()->void:
	if _context:
		if not _context.can_be_cancelled:
			return
		_context.cancel()
	complete()
## 失败处理方法：设置错误、打印并调用上下文的 complete()
## @seam
static func fail(context: CommandContext, msg_overriding: String = "") -> void:
	if not msg_overriding.is_empty():
		context.error = msg_overriding
		print("[%s] %s" % [context.command_name, context.error])
		context.complete()
## 卫语句：若对象为空，则调用 fail 并返回 true
## @operation(fail)
static func fail_if_null(obj: Object, context: CommandContext, msg: String) -> bool:
	if obj == null:
		fail(context, msg)
		return true
	return false
