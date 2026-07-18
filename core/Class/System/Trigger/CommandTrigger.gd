## 命令流程统一触发器：连接 CommandBus 信号到命令处理器，并处理修饰器。
extends SystemTrigger
class_name CommandTrigger

var _system: System

func _init(system: System) -> void:
	_system = system
	# 连接 CommandBus 的信号到命令处理器
	_system.command_bus.new_behavior.connect(_system.command_processor.queue_behavior)
	_system.command_bus.new_behavior_with_callback.connect(_on_new_behavior_with_callback)
	_system.command_processor.enable_processing.connect(_on_enable_processing)
	_system.command_processor.all_completed.connect(_on_all_completed)
	_system.command_processor.command_processing.connect(_on_command_processing)
	# 监听命令压入和弹出信号，同步上下文堆栈
	_system.command_processor.command_pushed.connect(_on_command_pushed)
	_system.command_processor.command_popped.connect(_on_command_popped)

func _on_new_behavior_with_callback(command: BehaviorCommand, callback: Callable) -> void:
	_system.command_processor.all_completed.connect(callback, CONNECT_ONE_SHOT)
	_system.command_processor.queue_behavior(command)

func _on_enable_processing(enable: bool) -> void:
	_system.game_state._process_active = enable
	_system.set_process(enable)

func _on_all_completed() -> void:
	_system.game_state.all_commands_completed.emit(_system.game_state)

func _on_command_processing(command: BehaviorCommand) -> void:
	_system.modifier_manager.process_modifiers(command._context, _system.game_state, _system.command_bus)

func _on_command_pushed(behavior: BehaviorCommand) -> void:
	_system.game_state.push_command_context(behavior._context)

func _on_command_popped(_behavior: BehaviorCommand) -> void:
	_system.game_state.pop_command_context()
