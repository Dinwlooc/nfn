## 命令上下文基类
extends RefCounted
class_name CommandContext

var player_id: int
## 命令类型标识
var command_name: StringName
## 命令阶段（执行进度）
var phase: int = 0
## 命令是否被视为完成。不影响命令的实际完成情况。
var is_completed: bool = false
##“取消”使该命令不做后续执行并立即结束。
var is_cancelled: bool = false
##“视为”前缀代表该命令将不执行实际效果，但修饰接口不变。
var is_virtual: bool = false
var can_be_cancelled: bool = true
static var NULL_CONTEXT:CommandContext = CommandContext.new()

func cancel() -> void:
	if can_be_cancelled:
		is_cancelled = true
## 撤销取消
func uncancel() -> void:
	if can_be_cancelled:
		is_cancelled = false
func virtualize() -> void:
	is_virtual = true
## 获取主修饰玩家ID数组（首位为命令发起者，其后为其他受影响的玩家）
func get_primary_modifier_player_ids() -> PackedInt32Array:
	return PackedInt32Array([player_id])
## 获取主修饰卡牌数组（首位为发起者拥有的卡牌，其后为其他受影响的卡牌）
func get_primary_modifier_cards() -> Array[Card]:
	return []
