## 游戏状态触发器基类。子类构造函数必须接收 [GameState] 和 [CommandBus]。
@abstract
extends RefCounted
class_name GameStateTrigger

## 关联的游戏状态
var _game_state: GameState
## 命令总线
var _command_bus: CommandBus
## 断开所有信号连接。子类必须覆盖此方法。
@abstract func disconnect_all() -> void
## 构造函数，自动持有依赖。
func _init(game_state: GameState, command_bus: CommandBus) -> void:
	_game_state = game_state
	_command_bus = command_bus
