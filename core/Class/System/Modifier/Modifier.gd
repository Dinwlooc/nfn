## 具体修饰器基类
## 修饰器是一种共用资源，官方会尽量复用修饰器资源。
## 因此，默认情况下，机制和数值都完全相同的效果总来自于同一个修饰器资源，机制完全相同的效果总来自同一个修饰器资源类脚本。
## 非官方的修饰器资源不一定满足这个条件。

extends Resource
class_name Modifier

## 掩码位定义
const DATA_MODIFIED: int = 1 << 0   # 是否对Context进行了数据修改
const COMMAND_SENT: int = 1 << 1   # 是否通过CommandBus发送了命令
const LOCK_SELF: int = 1 << 2      # 是否强制锁定自身（本轮次后续不再调用）
const ABORT_TRAVERSAL: int = 1 << 3 # 是否强制中止遍历

## 初始化，在 Card 或 Player 加载新修饰器时调用一次。
func init(source: Item) -> void:
	pass

## 主处理方法，应用修饰器效果。
## 返回掩码，描述本次处理的行为。
func process(context: CommandContext, state: GameState, command_bus: CommandBus, creator: Item) -> int:
	return 0  # 默认无任何效果
