extends RefCounted
class_name PlayersManager

var players: Array[Player] = []  # 按座位顺序存储玩家
var next_player_id: int = 1      # 下一个可分配的玩家ID
const ai_peer_id: int = -1          # AI控制的玩家peer_id固定为-1

# 添加玩家并分配ID和座位
func add_player(peer_id: int) -> Player:
	var player = Player.new()
	player.peer_id = peer_id
	player.player_id = next_player_id
	player.seat_index = players.size()  # 座位索引即数组位置
	player.HP_max = 20
	player.HP = 20
	player.init_AP = 3
	player.AP = player.init_AP
	player.draw_cards_count = 2
	players.append(player)
	next_player_id += 1

	return player

# 确保至少有min_players个玩家（不够时用AI补齐）
func ensure_min_players(min_players: int) -> void:
	while players.size() < min_players:
		add_player(ai_peer_id)  # 添加AI玩家

# 获取玩家数量
func get_player_count() -> int:
	return players.size()

# 通过座位索引获取玩家
func get_player_by_seat(seat_index: int) -> Player:
	if seat_index >= 0 and seat_index < players.size():
		return players[seat_index]
	return null

# 通过玩家ID获取玩家
func get_player_by_id(player_id: int) -> Player:
	for player in players:
		if player.player_id == player_id:
			return player
	return null

# 计算两个座位之间的距离
func calculate_distance(seat_index1: int, seat_index2: int) -> int:
	if players.size() == 0:
		return 0
	var n = players.size()
	var diff = abs(seat_index1 - seat_index2)
	return min(diff, n - diff)

# 验证对等体是否有操作权限
func has_permission(peer_id: int, seat_index: int) -> bool:
	var player = get_player_by_seat(seat_index)
	return player and player.peer_id == peer_id
