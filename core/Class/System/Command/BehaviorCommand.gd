extends BaseCommand
class_name BehaviorCommand

var event_name: StringName
var current_phase: int = 0
var _can_be_cancelled: bool = true  # 是否允许被取消
var is_cancelled: bool = false     # 当前取消状态

func execute(system: System) -> void:
	complete()

func cancel() -> void:
	if _can_be_cancelled:
		is_cancelled = true

func uncancel() -> void:
	if _can_be_cancelled:
		is_cancelled = false
