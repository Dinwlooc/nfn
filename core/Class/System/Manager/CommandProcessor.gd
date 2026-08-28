## 命令处理器：管理命令堆栈
class_name CommandProcessor
extends RefCounted

#=== Variables ===
## 命令堆栈（尾部为当前执行的命令）
var behavior_stack: Array[BehaviorCommand] = []
## 关联的游戏状态
var game_state: GameState
## 堆栈是否为空（缓存标志）
var is_empty: bool = true
## 动作序数，每次命令堆栈从非空变为空时自增
var _action_sequence: int = 0

#=== Signals ===
## 所有命令完成时发出
## @emitter
signal all_completed()
## 命令处理时发出，携带当前动作序数
## @emitter
signal command_processing(command: BehaviorCommand, sequence: int)
## 启用/禁用处理信号
## @emitter
signal enable_processing(_enable: bool)
## 命令压入堆栈时发出
## @emitter
signal command_pushed(behavior: BehaviorCommand)
## 命令从堆栈弹出时发出
## @emitter
signal command_popped(behavior: BehaviorCommand)

#=== Constructor ===
## 构造函数
## @side-effect
func _init(p_game_state: GameState) -> void:
	game_state = p_game_state

#=== Public Methods ===
## 处理命令堆栈
## @endo @emitter
func process() -> void:
	if behavior_stack.is_empty():
		if not is_empty:
			is_empty = true
			enable_processing.emit(false)
			all_completed.emit()
			_action_sequence += 1
		return
	var current_behavior: BehaviorCommand = behavior_stack.back()
	if current_behavior._is_completed:
		behavior_stack.pop_back()
		command_popped.emit(current_behavior)
		return
	command_processing.emit(current_behavior, _action_sequence)
	current_behavior.execute(game_state)
## 添加新命令到堆栈
## @endo @emitter
func queue_behavior(event: BehaviorCommand) -> void:
	event.companion_command_requested.connect(_on_companion_command_requested)
	behavior_stack.push_back(event)
	command_pushed.emit(event)
	if is_empty:
		is_empty = false
		enable_processing.emit(true)

#=== Private Methods ===
## 伴生命令请求处理
## @endo
func _on_companion_command_requested(command: BehaviorCommand) -> void:
	queue_behavior(command)
