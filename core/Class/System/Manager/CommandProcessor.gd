## 命令处理器：管理命令堆栈
class_name CommandProcessor
extends RefCounted
## 命令堆栈（尾部为当前执行的命令）
var behavior_stack: Array[BehaviorCommand] = []
var system: System
var is_empty: bool = true
## 所有命令完成时发出
signal all_completed()
## 命令完成一阶段处理时发出
signal command_processing(command: BehaviorCommand)
func _init(init_system: System) -> void:
	system = init_system
## 处理命令堆栈
func process() -> void:
	if behavior_stack.is_empty():
		if !is_empty:
			is_empty = true
			system.enable_processing(false)
			all_completed.emit()
		return
	var current_behavior: BehaviorCommand = behavior_stack.back()
	current_behavior.execute(system)
	command_processing.emit(current_behavior)
	if current_behavior.is_completed:
		behavior_stack.pop_back()
## 添加新命令到堆栈
func queue_behavior(event: BehaviorCommand) -> void:
	# 连接伴生命令信号（一次性连接）
	var connection = event.companion_command_requested.connect(
		_on_companion_command_requested, 
		CONNECT_ONE_SHOT
	)
	behavior_stack.push_back(event)
	if is_empty:
		is_empty = false
		system.enable_processing(true)
## 伴生命令请求处理
func _on_companion_command_requested(command: BehaviorCommand) -> void:
	queue_behavior(command)
