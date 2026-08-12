## 命令上下文基类
## 修饰器可以修改上下文内部的一切数据，但不是所有数据组合都被命令接受。
##	- 命令在执行时总是参考context中的部分数据以决定实际效果，且通常会对非法的数据组合做出静默修正。
## 	-有些数据不被命令所参考，但这些数据时可能间接影响其他修饰器的激活判定。
## 伴生源形成了一种链结构，以描述复杂命令。
##	-为了最大化链结构的自由度，Context通常要足够原子化。既是移动又是数据变更的Context，所对应的命令应当伴生一到两个命令去实现组合效果
##	-如果命令自己自己继承于某个原子操作，它可以少伴生一个命令，因为父类会完成相应的工作。
##	GDScript没有多态继承，目前的解决方案就是利用我们的栈结构去形成”链组”。我们会保持对其有效性的观察。
extends RefCounted
class_name CommandContext

var player_id: int
var command_name: StringName
var phase: int = 0
var is_completed: bool = false
var is_cancelled: bool = false
var is_virtual: bool = false
var can_be_cancelled: bool = true
var companion_source: WeakRef
static var NULL_CONTEXT: CommandContext = CommandContext.new()

func cancel() -> void:
	if can_be_cancelled:
		is_cancelled = true

func uncancel() -> void:
	if can_be_cancelled:
		is_cancelled = false

func virtualize() -> void:
	is_virtual = true

## 获取主修饰卡牌列表（第一优先），默认空，子类可重写
func get_primary_modifier_cards() -> Array[Card]:
	return []

## 获取主修饰玩家列表（第二优先），默认空，子类可重写
func get_primary_modifier_players() -> Array[Player]:
	return []

func set_companion_source(new_companion_source: CommandContext) -> CommandContext:
	companion_source = weakref(new_companion_source)
	return self

func get_companion_source() -> CommandContext:
	return companion_source.get_ref()
