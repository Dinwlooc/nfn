## 命令处理器：管理命令堆栈
class_name CommandProcessor
extends RefCounted

## 命令堆栈（尾部为当前执行的命令）
var behavior_stack: Array[BehaviorCommand] = []
var game_state: GameState
var is_empty: bool = true

## 动作序数，每次命令堆栈从非空变为空时自增
var _action_sequence: int = 0

## 所有命令完成时发出
signal all_completed()
## 命令处理时发出，携带当前动作序数
signal command_processing(command: BehaviorCommand, sequence: int)
signal enable_processing(_enable: bool)
## 命令压入堆栈时发出，携带命令实例
signal command_pushed(behavior: BehaviorCommand)
## 命令从堆栈弹出时发出，携带命令实例
signal command_popped(behavior: BehaviorCommand)

func _init(p_game_state: GameState) -> void:
	game_state = p_game_state

## 处理命令堆栈
func process() -> void:
	if behavior_stack.is_empty():
		if !is_empty:
			is_empty = true
			enable_processing.emit(false)
			all_completed.emit()
			_action_sequence += 1  # 堆栈变空后自增
		return
	var current_behavior: BehaviorCommand = behavior_stack.back()
	if current_behavior._is_completed:
		behavior_stack.pop_back()
		command_popped.emit(current_behavior)
		return
	command_processing.emit(current_behavior, _action_sequence)
	current_behavior.execute(game_state)

## 添加新命令到堆栈
func queue_behavior(event: BehaviorCommand) -> void:
	event.companion_command_requested.connect(_on_companion_command_requested)
	behavior_stack.push_back(event)
	command_pushed.emit(event)
	if is_empty:
		is_empty = false
		enable_processing.emit(true)

## 伴生命令请求处理
func _on_companion_command_requested(command: BehaviorCommand) -> void:
	queue_behavior(command)
