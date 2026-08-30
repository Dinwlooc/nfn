## 玩家管理器，负责维护玩家列表、座位分配及增量包缓存管理
extends RefCounted
class_name PlayersManager

#=== Variables ===
## 按座位顺序存储玩家实例
var players: Array[Player] = []
## 内置 ID 映射字典（玩家 ID -> 实例）
var _players_by_id: Dictionary[int, Player] = {}
## 下一个可分配的玩家 ID
var _next_player_id: int = 2

#=== Constants ===
## AI 控制的玩家 peer_id 固定为 -1
const ai_peer_id: int = -1

#=== Signals ===
## 玩家添加信号
## @emitter
signal player_added(player: Player)

const PLAYER_AREA: StringName = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.PLAYERS]

#=== Public Methods ===
## 添加玩家并分配 ID 和座位
## @internal @emitter
func add_player(peer_id: int) -> Player:
	var player: Player = Player.new()
	player.peer_id = peer_id
	player.set_id(_next_player_id)
	player.seat_index = players.size()
	player.recover_to_full()
	players.append(player)
	player_added.emit(player)
	_players_by_id[_next_player_id] = player
	_next_player_id += 1
	return player
## 通过座位索引移除玩家
## @internal
func remove_player_from_seat(seat_index: int) -> Player:
	if seat_index < 0 or seat_index >= players.size():
		return null
	var removed_player: Player = players.pop_at(seat_index)
	for i: int in range(seat_index, players.size()):
		players[i].seat_index = i
	return removed_player
## 通过玩家 ID 移除座位上的玩家
## @internal
func remove_player_by_id(player_id: int) -> Player:
	var player: Player = _players_by_id.get(player_id)
	if player == null:
		return null
	var seat_idx: int = player.seat_index
	if seat_idx < 0 or seat_idx >= players.size() or players[seat_idx] != player:
		return null
	return remove_player_from_seat(seat_idx)
## 将已有玩家插入到指定座位
## @internal
func insert_player_at_seat(player: Player, seat_index: int) -> bool:
	if player == null:
		return false
	if seat_index < 0 or seat_index > players.size():
		return false
	if players.has(player):
		return false
	if not _players_by_id.has(player.player_id):
		_players_by_id[player.player_id] = player
	players.insert(seat_index, player)
	for i: int in range(seat_index, players.size()):
		players[i].seat_index = i
	return true
## 确保至少有 min_players 个玩家（不够时用 AI 补齐）
## @internal
func ensure_min_players(min_players: int) -> void:
	while players.size() < min_players:
		add_player(ai_peer_id)
## 获取当前在座玩家数量
## @pure
func get_player_count() -> int:
	return players.size()
## 获取当前所有在座玩家
## @pure
func get_seated_players() -> Array[Player]:
	return players
## 通过座位索引获取玩家
## @pure
func get_player_by_seat(seat_index: int) -> Player:
	if seat_index >= 0 and seat_index < players.size():
		return players[seat_index]
	return null
## 通过玩家 ID 获取玩家
## @pure
func get_player_by_id(player_id: int) -> Player:
	return _players_by_id.get(player_id)
## 批量获取玩家
## @pure
func get_players_by_ids(players_ids: PackedInt32Array) -> Array[Player]:
	var _players: Array[Player] = []
	_players.resize(players_ids.size())
	for i in players_ids.size():
		_players[i] = get_player_by_id(players_ids[i])
	return _players
## 计算两个座位之间的最短距离（环形布局）
## @pure
func calculate_distance(seat_index1: int, seat_index2: int) -> int:
	if players.size() == 0:
		return 0
	var n: int = players.size()
	var diff: int = abs(seat_index1 - seat_index2)
	return min(diff, n - diff)
## 获得指定玩家的禁用操作
## @pure
func get_operation_disallowed(player_id: int) -> Array[StringName]:
	var player: Player = _players_by_id.get(player_id)
	return player.disallowed_operations
## 清除所有玩家的增量包缓存
## @internal
func clear_all_players_cache() -> void:
	for player: Player in players:
		player.clear_pack_cache()
## 获取指定玩家的当前增量包（用于调试）
## @pure
func get_player_delta_pack(player_id: int) -> PlayerPack:
	var player: Player = _players_by_id.get(player_id)
	if player:
		return player.get_pack()
	return null
## 获取指定玩家的全量包（用于调试）
## @pure
func get_player_full_pack(player_id: int) -> PlayerPack:
	var player: Player = _players_by_id.get(player_id)
	if player:
		return player.get_full_pack()
	return null
## 通过玩家 ID 获取座位索引
## @pure
func get_seat_index_by_player_id(player_id: int) -> int:
	var player: Player = _players_by_id.get(player_id)
	return player.seat_index if player else -1

#=== Private Methods ===
## 从单个玩家实例获取增量包（如果无变化则返回 null）
## @pure
func _get_player_delta_pack(player: Player) -> PlayerPack:
	var pack: PlayerPack = player.get_pack()
	return pack if pack.merge_mask != 0 else null
