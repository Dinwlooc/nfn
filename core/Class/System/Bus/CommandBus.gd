## 命令总线（独立，不依赖 GameState）
extends RefCounted
class_name CommandBus

## 命令已入队（无回调）
## @emitter
signal new_behavior(command: BehaviorCommand)
## 命令已入队（带完成回调）
## @emitter
signal new_behavior_with_callback(command: BehaviorCommand, callback: Callable)
## 传唤：设置可响应玩家集合（由操作处理器接管）
## @requester
signal request_set_responsive_players(player_ids: PackedInt32Array)

## 入队不带回调的命令
func queue_behavior(command: BehaviorCommand) -> void:
	new_behavior.emit(command)

## 入队带回调的命令
func queue_behavior_with_callback(command: BehaviorCommand, callback: Callable) -> void:
	new_behavior_with_callback.emit(command, callback)

## 设置可响应玩家（发出信号，由 OperationHandler 处理）
func set_responsive_players(player_ids: PackedInt32Array) -> void:
	request_set_responsive_players.emit(player_ids)
