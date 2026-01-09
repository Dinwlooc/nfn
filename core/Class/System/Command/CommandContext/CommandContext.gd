## 命令上下文基类
extends RefCounted
class_name CommandContext

var player_id:int
## 命令类型标识
var event_name: StringName
## 命令阶段（执行进度）
var phase: int = 0
## 命令是否被视为完成。不影响命令的实际完成情况。
var is_completed: bool = false
##“取消”使该命令不做后续执行并立即结束。
var is_cancelled: bool = false
##“视为”前缀代表该命令将不执行实际效果，但修饰接口不变。
var is_virtual:bool = false
var can_be_cancelled: bool = true

func cancel() -> void:
	if can_be_cancelled:
		is_cancelled = true
## 撤销取消
func uncancel() -> void:
	if can_be_cancelled:
		is_cancelled = false

func virtualize()->void:
	is_virtual = true
