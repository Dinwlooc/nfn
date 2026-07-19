## 具体修饰器基类
## 修饰器有多种来源，一种在官方以内部资源形式挂载在ItemData上，另一种被buff动态加载到Item实例上。
## 修饰器通常复用同一个资源。这包括使用同一份ItemData的Item或同一Buff附加修饰器。
## 因此，修饰器资源本身不保存运行时状态。可以通过process返回值向CommandModifiers上传运行时上下文。
extends Resource
class_name Modifier

## 初始化，在 Card 或 Player 加载新修饰器时调用一次。
func init(source: Item) -> void:
	pass

## 主处理方法，应用修饰器效果。
## @param context 命令上下文
## @param state 游戏状态
## @param modifier_ctx 传入的修饰器上下文（用于外部传入初始状态或供修饰器修改）
## @param creator 挂载此修饰器的 Item（通常为 Card）
## @return 处理后的 ModifierContext（通常直接返回修改后的 modifier_ctx）
func process(context: CommandContext, state: GameState, modifier_ctx: ModifierContext, creator: Item) -> ModifierContext:
	return modifier_ctx  # 默认不做任何修改

## 辅助方法：检查时机并执行前置检查（挂载者是否为 Card，以及时机是否匹配）
## @param timing 时机枚举（来自 RuleModifierTiming.Timing）
## @param ctx 命令上下文
## @param creator 挂载者（Item）
## @return 若检查通过则返回 true，否则 false
func _check_timing(timing: int, ctx: CommandContext, creator: Item) -> bool:
	if not (creator is Card):
		return false
	if not RuleModifierTiming.check(ctx, creator as Card, timing):
		return false
	return true

## 辅助方法：将命令加入修饰器上下文的待发送队列，并自动设置 COMMAND_SENT 标志
## @param command 要发送的命令
## @param modifier_ctx 要修改的 ModifierContext
func _send_command(command: BehaviorCommand, modifier_ctx: ModifierContext) -> void:
	modifier_ctx.add_command(command)
	modifier_ctx.set_work_flag(ModifierContext.COMMAND_SENT)
