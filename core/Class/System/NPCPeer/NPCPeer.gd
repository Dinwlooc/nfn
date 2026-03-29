extends RefCounted
class_name NPCPeer

var _game_state: GameState
var _player_id: int

## 初始化 NPC，传入游戏状态和所属玩家 ID
func _init(game_state: GameState, player_id: int) -> void:
	_game_state = game_state
	_player_id = player_id

## NPC在行动前的趣味性互动（可重写）
func await_npc_ready():
	pass

## 异步决策接口：子类必须实现此方法，决策完成后调用 callback，传入 OperationRequest 或 null
## @param callback: Callable 接受一个参数（OperationRequest 或 null）
func request_decision_async(callback: Callable) -> void:
	push_error("子类必须实现 request_decision_async")

## 清理资源，子类可重写
func cleanup() -> void:
	pass
