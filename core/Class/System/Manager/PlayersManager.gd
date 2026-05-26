## 玩家管理器，负责维护玩家列表、座位分配及增量包缓存管理
extends RefCounted
class_name PlayersManager

var players: Array[Player] = []              ## 按座位顺序存储玩家实例
var _players_by_id: Dictionary[int, Player] = {}          ## 内置ID映射字典（玩家ID->实例）
var _next_player_id: int = 2                 ## 内置缓存：下一个可分配的玩家ID
const ai_peer_id: int = -1                   ## AI控制的玩家peer_id固定为-1
signal player_added(player: Player)
const PLAYER_AREA: StringName = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.PLAYERS]

## 添加玩家并分配ID和座位，返回创建的玩家实例
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

## 通过座位索引移除玩家（被移除玩家保留在映射表中，后方玩家座位前移）
func remove_player_from_seat(seat_index: int) -> Player:
	if seat_index < 0 or seat_index >= players.size():
		return null
	var removed_player: Player = players.pop_at(seat_index)
	for i: int in range(seat_index, players.size()):
		players[i].seat_index = i
	return removed_player

## 通过玩家ID移除座位上的玩家（若玩家当前在座），保留映射并调整后方座位
func remove_player_by_id(player_id: int) -> Player:
	var player: Player = _players_by_id.get(player_id)
	if player == null:
		return null
	var seat_idx: int = player.seat_index
	if seat_idx < 0 or seat_idx >= players.size() or players[seat_idx] != player:
		return null
	return remove_player_from_seat(seat_idx)

## 将已有玩家插入到指定座位，原座位及之后玩家向后移位
func insert_player_at_seat(player: Player, seat_index: int) -> bool:
	if player == null:
		return false
	if seat_index < 0 or seat_index > players.size():
		return false
	# 如果玩家已经在座位数组中（即已在座），不允许重复插入
	if players.has(player):
		return false
	# 确保玩家在映射表中（若尚未加入则加入）
	if not _players_by_id.has(player.player_id):
		_players_by_id[player.player_id] = player
	# 插入座位：将 seat_index 及之后的玩家向后移动一位
	players.insert(seat_index, player)
	# 更新从 seat_index 开始的所有玩家的 seat_index
	for i: int in range(seat_index, players.size()):
		players[i].seat_index = i
	return true

## 确保至少有min_players个玩家（不够时用AI补齐）
func ensure_min_players(min_players: int) -> void:
	while players.size() < min_players:
		add_player(ai_peer_id)

## 获取当前在座位上的玩家数量
func get_player_count() -> int:
	return players.size()

## 获取当前所有在座玩家（直接返回内部数组引用）
func get_seated_players() -> Array[Player]:
	return players

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
	var n: int = players.size()
	var diff: int = abs(seat_index1 - seat_index2)
	return min(diff, n - diff)

## 获得指定玩家的禁用操作
func get_operation_disallowed(player_id: int) -> Array[StringName]:
	var player: Player = _players_by_id.get(player_id)
	return player.disallowed_operations

## 从单个玩家实例获取增量包（如果无变化则返回null）
func _get_player_delta_pack(player: Player) -> PlayerPack:
	var pack: PlayerPack = player.get_pack()
	return pack if pack.merge_mask != 0 else null

## 清除所有玩家的增量包缓存
func clear_all_players_cache() -> void:
	for player: Player in players:
		player.clear_pack_cache()

## 获取指定玩家的当前增量包（用于调试或验证）
func get_player_delta_pack(player_id: int) -> PlayerPack:
	var player: Player = _players_by_id.get(player_id)
	if player:
		return player.get_pack()
	return null

## 获取指定玩家的全量包（用于调试或验证）
func get_player_full_pack(player_id: int) -> PlayerPack:
	var player: Player = _players_by_id.get(player_id)
	if player:
		return player.get_full_pack()
	return null

## 通过玩家ID获取座位索引，若玩家不存在则返回-1
func get_seat_index_by_player_id(player_id: int) -> int:
	var player: Player = _players_by_id.get(player_id)
	return player.seat_index if player else -1
