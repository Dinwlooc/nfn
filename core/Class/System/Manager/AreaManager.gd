extends RefCounted
class_name AreaManager

var _game_state: GameState

func _init(game_state: GameState) -> void:
	_game_state = game_state

## 连接区域，监听其请求命令入栈信号
func connect_area(area: Area) -> void:
	# 注意：使用 signal 的 connect 方法，避免重复连接
	if not area.area_request_command.is_connected(_on_area_request_command):
		area.area_request_command.connect(_on_area_request_command)
	if not area.area_request_command_with_callback.is_connected(_on_area_request_command_with_callback):
		area.area_request_command_with_callback.connect(_on_area_request_command_with_callback)

func _on_area_request_command(command: BehaviorCommand) -> void:
	_game_state.queue_behavior(command)

func _on_area_request_command_with_callback(command: BehaviorCommand, callback: Callable) -> void:
	_game_state.queue_behavior_with_callback(command, callback)
