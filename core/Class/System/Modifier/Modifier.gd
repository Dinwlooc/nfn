## 具体修饰器基类
extends Resource
class_name Modifier

enum ModifierResult {
	PASS,   # 不生效，继续
	WORK,   # 生效，正常
	LOCK,   # 锁定后续处理
}

## 初始化，在 Card 或 Player 加载新修饰器时调用一次。
func init(source: Item) -> void:
	pass

## 主处理方法，应用修饰器效果。
## 返回 ModifierResult 指示处理状态。
func process(context: CommandContext, state: GameState, command_bus: CommandBus, creator: Item) -> ModifierResult:
	return ModifierResult.WORK
