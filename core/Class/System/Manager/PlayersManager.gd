extends RefCounted
class_name PlayersManager

var players: Array[Player] = []              ## 按座位顺序存储玩家实例
var _players_by_id: Dictionary = {}          ## 内置ID映射字典（玩家ID->实例）
var _next_player_id: int = 0                 ## 内置缓存：下一个可分配的玩家ID
const ai_peer_id: int = -1                   ## AI控制的玩家peer_id固定为-1
signal peer_player_added(peer_id: int, player_id: int)
## 添加玩家并分配ID和座位，返回创建的玩家实例
func add_player(peer_id: int) -> Player:
	var player = Player.new()
	player.peer_id = peer_id
	player.player_id = _next_player_id
	player.seat_index = players.size()       # 座位索引即数组位置
	players.append(player)
	peer_player_added.emit(peer_id, _next_player_id)
	_players_by_id[_next_player_id] = player   # 添加到ID映射字典
	_next_player_id += 1
	return player
## 移除指定座位的玩家并调整后方玩家的座位
func remove_player_from_seat(seat_index: int) -> Player:
	if seat_index < 0 or seat_index >= players.size():
		return null
	var removed_player = players.pop_at(seat_index)
	for i in range(seat_index, players.size()):
		players[i].seat_index = i
	return removed_player
## 确保至少有min_players个玩家（不够时用AI补齐）
func ensure_min_players(min_players: int) -> void:
	while players.size() < min_players:
		add_player(ai_peer_id)               # 添加AI玩家
## 获取当前在座位上的玩家数量
func get_player_count() -> int:
	return players.size()
## 通过座位索引获取玩家（无效索引返回null）
func get_player_by_seat(seat_index: int) -> Player:
	if seat_index >= 0 and seat_index < players.size():
		return players[seat_index]
	return null
## 通过玩家ID获取玩家（无效ID返回null）
func get_player_by_id(player_id: int) -> Player:
	return _players_by_id.get(player_id)
## 计算两个座位之间的最短距离（环形布局）
func calculate_distance(seat_index1: int, seat_index2: int) -> int:
	if players.size() == 0:
		return 0
	var n = players.size()
	var diff = abs(seat_index1 - seat_index2)
	return min(diff, n - diff)
## 获得指定玩家的禁用操作
func get_operation_disallowed(player_id: int) -> Array[StringName]:
	var player:Player = _players_by_id.get(player_id)
	return player.disallowed_operations
