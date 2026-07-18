## 命令总线
extends RefCounted
class_name CommandBus

var _game_state: GameState

signal request_set_responsive_players(player_ids: PackedInt32Array)

func _init(game_state: GameState) -> void:
	_game_state = game_state

## 入队不带回调的命令
func queue_behavior(command: BehaviorCommand) -> void:
	_game_state.queue_behavior(command)

## 入队带回调的命令
func queue_behavior_with_callback(command: BehaviorCommand, callback: Callable) -> void:
	_game_state.queue_behavior_with_callback(command, callback)

## 设置可响应玩家（发出信号，由 OperationHandler 处理）
func set_responsive_players(player_ids: PackedInt32Array) -> void:
	request_set_responsive_players.emit(player_ids)
