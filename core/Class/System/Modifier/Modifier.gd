## 具体修饰器实现：链接到内部可调用体的中转类
extends RefCounted
class_name Modifier
## 初始化，在 Card 或 Player 加载新修饰器时调用一次。
## @param source: 修饰器附着的主体对象（Card 或 Player）
static func init(source: Object) -> void:
	pass
## 主处理方法，用于应用修饰器效果。
static func process(context: CommandContext, state: GameState, creator: Object) -> void:
	pass
