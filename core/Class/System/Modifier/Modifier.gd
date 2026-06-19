## 具体修饰器
extends RefCounted
class_name Modifier
## 初始化，在 Card 或 Player 加载新修饰器时调用一次。
static func init(source: Item) -> void:
	pass
## 主处理方法，用于应用修饰器效果。
static func process(context: CommandContext, state: GameState, creator: Item) -> void:
	pass
