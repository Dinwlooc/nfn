## 命令总线
extends RefCounted
class_name CommandBus

var _game_state: GameState

func _init(game_state: GameState) -> void:
	_game_state = game_state

## 入队不带回调的命令
func queue_behavior(command: BehaviorCommand) -> void:
	_game_state.queue_behavior(command)

## 入队带回调的命令
func queue_behavior_with_callback(command: BehaviorCommand, callback: Callable) -> void:
	_game_state.queue_behavior_with_callback(command, callback)
