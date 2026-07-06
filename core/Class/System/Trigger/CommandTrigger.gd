## 命令流程统一触发器：连接 new_behavior、命令处理器生命周期、修饰器。
extends SystemTrigger
class_name CommandTrigger

var _system: System

func _init(system: System) -> void:
	_system = system
	_system.game_state.new_behavior.connect(_system.command_processor.queue_behavior)
	_system.game_state.new_behavior_with_callback.connect(_on_new_behavior_with_callback)
	_system.command_processor.enable_processing.connect(_on_enable_processing)
	_system.command_processor.all_completed.connect(_on_all_completed)
	_system.command_processor.command_processing.connect(_on_command_processing)

func _on_new_behavior_with_callback(command: BehaviorCommand, callback: Callable) -> void:
	_system.command_processor.all_completed.connect(callback, CONNECT_ONE_SHOT)
	_system.command_processor.queue_behavior(command)

func _on_enable_processing(enable: bool) -> void:
	_system.game_state._process_active = enable
	_system.set_process(enable)
## 所有命令完成时：通知外界
func _on_all_completed() -> void:
	_system.game_state.all_commands_completed.emit(_system.game_state)

func _on_command_processing(command: BehaviorCommand) -> void:
	_system.modifier_manager.process_modifiers(command._context, _system.game_state)
