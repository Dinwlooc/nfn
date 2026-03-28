## 命令处理器：管理命令堆栈
class_name CommandProcessor
extends RefCounted
## 命令堆栈（尾部为当前执行的命令）
var behavior_stack: Array[BehaviorCommand] = []
var game_state: GameState
var is_empty: bool = true
## 所有命令完成时发出
signal all_completed()
signal command_processing(command: BehaviorCommand)
signal enable_processing(_enable:bool)

func _init(p_game_state: GameState) -> void:
	game_state = p_game_state
## 处理命令堆栈
func process() -> void:
	if behavior_stack.is_empty():
		if !is_empty:
			is_empty = true
			enable_processing.emit(false)
			all_completed.emit()
			game_state.all_commands_completed.emit()
		return
	var current_behavior: BehaviorCommand = behavior_stack.back()
	if current_behavior._is_completed:
		behavior_stack.pop_back()
		return
	command_processing.emit(current_behavior)
	current_behavior.execute(game_state)

## 添加新命令到堆栈
func queue_behavior(event: BehaviorCommand) -> void:
	event.companion_command_requested.connect(_on_companion_command_requested)
	behavior_stack.push_back(event)
	if is_empty:
		is_empty = false
		enable_processing.emit(true)
## 伴生命令请求处理
func _on_companion_command_requested(command: BehaviorCommand) -> void:
	queue_behavior(command)
