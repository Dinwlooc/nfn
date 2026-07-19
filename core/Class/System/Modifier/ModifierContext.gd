## 修饰器上下文，作为 Modifier.process 的返回值，用于向 CommandModifiers 报告本次处理结果。
## 它包含工作掩码（描述修饰器执行了哪些操作）、错误码以及待发送的命令队列。
## 命令队列由 CommandModifiers 在调用 process 后统一发送并清空，避免命令直接依赖 CommandBus。
extends RefCounted
class_name ModifierContext

const DATA_MODIFIED: int = 1 << 0
const COMMAND_SENT: int = 1 << 1

const ERR_NONE: int = 0
const ERR_INVALID_TARGET: int = 1
const ERR_RESOURCE_INSUFFICIENT: int = 2
const ERR_STATE_INVALID: int = 3
const ERR_OTHER: int = 999

var work_mask: int = 0
var error_code: int = ERR_NONE

## 待发送的命令列表，由修饰器添加，由 CommandModifiers 发送并清空
var _pending_commands: Array[BehaviorCommand] = []
## 添加一个待发送的命令
## @param command 要发送的命令
## @return 自身，便于链式调用
func add_command(command: BehaviorCommand) -> ModifierContext:
	_pending_commands.append(command)
	return self

## 获取并清空待发送的命令列表（由 CommandModifiers 调用）
func take_commands() -> Array[BehaviorCommand]:
	var cmds:Array[BehaviorCommand] = _pending_commands
	_pending_commands = []
	return cmds

## 检查是否有待发送的命令
func has_pending_commands() -> bool:
	return not _pending_commands.is_empty()

## 设置工作标志，支持链式
func set_work_flag(flag: int) -> ModifierContext:
	work_mask |= flag
	return self

## 检查是否包含指定标志
func has_work_flag(flag: int) -> bool:
	return (work_mask & flag) != 0

## 设置错误码，仅当无错误时生效，支持链式
func set_error(code: int) -> ModifierContext:
	if error_code == ERR_NONE:
		error_code = code
	return self
## 是否成功
func is_success() -> bool:
	return error_code == ERR_NONE
## 工厂方法
static func command_sent() -> ModifierContext:
	return ModifierContext.new().set_work_flag(COMMAND_SENT)

static func data_modified() -> ModifierContext:
	return ModifierContext.new().set_work_flag(DATA_MODIFIED)

static func error(code: int) -> ModifierContext:
	return ModifierContext.new().set_error(code)
