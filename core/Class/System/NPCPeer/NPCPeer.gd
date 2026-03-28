extends RefCounted
class_name NPCPeer
var _game_state: GameState
var _player_id: int

## 初始化 NPC，传入游戏状态和所属玩家 ID
func _init(game_state: GameState, player_id: int) -> void:
	_game_state = game_state
	_player_id = player_id

## npc在行动前的趣味性互动。
func await_npc_ready():
	pass
## 子类实现自己的决策逻辑，返回一个 OperationRequest 或 null
## 如果返回非空请求，NPCPeerManager 会发射 operation_requested 信号并处理取消重试。
func get_operation_request() -> OperationRequest:
	return null

## 清理资源，子类可重写
func cleanup() -> void:
	pass
