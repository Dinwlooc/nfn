## 修饰运行时规则，提供基于 ModifierContext 的决策。
extends RefCounted
class_name RuleModifierRuntime

## 根据上下文判断是否应跳过本次修饰器执行。
## 当前规则：如果上下文已发送命令（COMMAND_SENT），则跳过。
static func should_skip(context: ModifierContext) -> bool:
	return context.has_work_flag(ModifierContext.COMMAND_SENT)
