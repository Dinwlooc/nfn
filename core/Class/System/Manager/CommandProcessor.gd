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
## @side_effect
func _init(p_game_state: GameState) -> void:
	game_state = p_game_state
#=== Public Methods ===
## 处理命令堆栈
## @internal @emitter
func process() -> void:
	# 先检查堆栈是否为空，与原逻辑一致
	if behavior_stack.is_empty():
		if not is_empty:
			is_empty = true
			enable_processing.emit(false)
			all_completed.emit()
			_action_sequence += 1
		return
	# 弹出所有已完成命令，获取第一个可执行命令
	var executable: BehaviorCommand = _pop_to_executable()
	if executable == null:
		return
	# 执行该命令
	command_processing.emit(executable, _action_sequence)
	executable.execute(game_state)
## 添加新命令到堆栈
## @internal @emitter
func queue_behavior(event: BehaviorCommand) -> void:
	event.companion_command_requested.connect(_on_companion_command_requested)
	behavior_stack.push_back(event)
	command_pushed.emit(event)
	if is_empty:
		is_empty = false
		enable_processing.emit(true)
#=== Private Methods ===
## 弹出所有已完成命令，返回栈顶第一个可执行命令（未完成），若堆栈为空则返回 null
## 使用索引遍历，统计栈顶连续已完成的命令数量，然后通过 resize() 一次性移除并收缩容量（不拷贝）
## @internal @emitter
func _pop_to_executable() -> BehaviorCommand:
	var size: int = behavior_stack.size()
	var i: int = size - 1  # 从尾部开始向前扫描
	# 找出栈顶连续已完成的命令（即尾部连续 _is_completed == true）
	while i >= 0 and behavior_stack[i]._is_completed:
		i -= 1
	# 完成命令的数量 = (size - 1) - i
	var completed_count: int = size - 1 - i
	# 若有已完成命令，先发射信号，再 resize 移除
	if completed_count > 0:
		# 从后往前发射 command_popped 信号
		for j in range(size - 1, i, -1):
			command_popped.emit(behavior_stack[j])
		# 调整数组大小，保留索引 0..i 的元素，尾部已完成命令被丢弃
		behavior_stack.resize(i + 1)
	if behavior_stack.is_empty():
		return null
	return behavior_stack.back()
## 伴生命令请求处理
## @internal
func _on_companion_command_requested(command: BehaviorCommand) -> void:
	queue_behavior(command)
