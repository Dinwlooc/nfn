## 游戏状态触发器标记。子类构造函数必须接收 [GameState] 实例。
## 用于仅依赖游戏状态的场景。
extends RefCounted
class_name GameStateTrigger

var _game_state:GameState

func _init(game_state: GameState) -> void:
	_game_state = game_state
