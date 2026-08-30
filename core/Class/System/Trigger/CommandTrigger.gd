extends SystemTrigger
class_name CommandTrigger

func _init(system: System) -> void:
	super._init(system)
	_system.command_bus.new_behavior.connect(_system.command_processor.queue_behavior)
	_system.command_bus.new_behavior_with_callback.connect(_on_new_behavior_with_callback)
	_system.command_processor.enable_processing.connect(_on_enable_processing)
	_system.command_processor.all_completed.connect(_on_all_completed)
	_system.command_processor.command_processing.connect(_on_command_processing)
	_system.command_processor.command_pushed.connect(_on_command_pushed)
	_system.command_processor.command_popped.connect(_on_command_popped)
## @signal_listener 带回调的命令压入
func _on_new_behavior_with_callback(command: BehaviorCommand, callback: Callable) -> void:
	_system.command_processor.all_completed.connect(callback, CONNECT_ONE_SHOT)
	_system.command_processor.queue_behavior(command)
## @signal_listener 处理开关
func _on_enable_processing(enable: bool) -> void:
	_system.game_state._process_active = enable
	_system.set_process(enable)
## @signal_listener 所有命令完成
func _on_all_completed() -> void:
	_system.game_state.all_commands_completed.emit(_system.game_state)
## @signal_listener 命令处理时触发修饰器
func _on_command_processing(command: BehaviorCommand, sequence: int) -> void:
	_system.modifier_manager.process_modifiers(command._context, _system.game_state, _system.command_bus, sequence)
## @signal_listener 命令压入上下文栈
func _on_command_pushed(behavior: BehaviorCommand) -> void:
	_system.game_state.push_command_context(behavior._context)
## @signal_listener 命令弹出上下文栈
func _on_command_popped(_behavior: BehaviorCommand) -> void:
	_system.game_state.pop_command_context()
##
func disconnect_all() -> void:
	_system.command_bus.new_behavior.disconnect(_system.command_processor.queue_behavior)
	_system.command_bus.new_behavior_with_callback.disconnect(_on_new_behavior_with_callback)
	_system.command_processor.enable_processing.disconnect(_on_enable_processing)
	_system.command_processor.all_completed.disconnect(_on_all_completed)
	_system.command_processor.command_processing.disconnect(_on_command_processing)
	_system.command_processor.command_pushed.disconnect(_on_command_pushed)
	_system.command_processor.command_popped.disconnect(_on_command_popped)
