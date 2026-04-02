extends RefCounted
class_name NetworkManager

enum ConnectionState { DISCONNECTED, CONNECTING, CONNECTED }

var peer = WebSocketMultiplayerPeer.new()
var users: Dictionary[int,User]  # 改用字典，key为peer_id
var url: String
var connection_state: ConnectionState = ConnectionState.DISCONNECTED
var multiplayer_api: MultiplayerAPI

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connection_succeeded()
signal connection_failed()
signal connection_closed()

func set_multiplayer(multiplayer: MultiplayerAPI) -> void:
	multiplayer_api = multiplayer
	multiplayer.connected_to_server.connect(_on_multiplayer_connected_to_server)
	multiplayer.connection_failed.connect(_on_multiplayer_connection_failed)
	multiplayer.server_disconnected.connect(_on_multiplayer_server_disconnected)
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)

func _init() -> void:
	GlobalConsole._print("NetworkManager: 网络管理器初始化完成")

func poll() -> void:
	if connection_state == ConnectionState.CONNECTING:
		var status = peer.get_connection_status()
		if status == MultiplayerPeer.CONNECTION_CONNECTED:
			connection_state = ConnectionState.CONNECTED
			GlobalConsole._print("NetworkManager: 连接成功")
			connection_succeeded.emit()
		elif status == MultiplayerPeer.CONNECTION_DISCONNECTED:
			connection_state = ConnectionState.DISCONNECTED
			GlobalConsole._print("NetworkManager: 连接失败")
			connection_failed.emit()
	peer.poll()
# 从 peer 获取当前连接的 id
func get_current_id() -> int:
	if peer and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		return peer.get_unique_id()
	return -1
# 服务器启动
func random_create() -> bool:
	var port = randi_range(1024, 65535)
	if peer.create_server(port) == OK:
		url = "ws://localhost:" + str(port)
		connection_state = ConnectionState.CONNECTED
		var current_id = get_current_id()
		if current_id != -1:
			var user := User.new()
			user.id = current_id
			user.get_config()
			users[current_id] = user
			peer_connected.emit(current_id)
		GlobalConsole._print(["NetworkManager: 服务器成功启动:ws://localhost:", port])
		multiplayer_api.multiplayer_peer = peer
		connection_succeeded.emit()
		return true
	return false

# 客户端连接
func url_connect(new_url: String) -> bool:
	if connection_state != ConnectionState.DISCONNECTED:
		close()
	GlobalConsole._print(["NetworkManager: 尝试连接到: ", new_url])
	if peer.create_client(new_url) == OK:
		connection_state = ConnectionState.CONNECTING
		return true
	return false

func close() -> void:
	peer.close()
	users.clear()
	connection_state = ConnectionState.DISCONNECTED
	GlobalConsole._print("NetworkManager: 网络连接已关闭")

func get_user_count() -> int:
	return users.size()

func get_peer() -> WebSocketMultiplayerPeer:
	return peer

# MultiplayerAPI 信号处理函数
func _on_multiplayer_connected_to_server() -> void:
	GlobalConsole._print("NetworkManager: 已连接到服务器")
	var current_id = get_current_id()
	if current_id != -1:
		var user := User.new()
		user.id = current_id
		user.get_config()
		users[current_id] = user
		peer_connected.emit(current_id)
		multiplayer_api.multiplayer_peer = peer

func _on_multiplayer_connection_failed() -> void:
	GlobalConsole._print("NetworkManager: 连接失败")
	connection_state = ConnectionState.DISCONNECTED
	connection_failed.emit()

func _on_multiplayer_server_disconnected() -> void:
	GlobalConsole._print("NetworkManager: 服务器断开连接")
	connection_state = ConnectionState.DISCONNECTED
	users.clear()
	connection_closed.emit()

func _on_multiplayer_peer_connected(peer_id: int) -> void:
	GlobalConsole._print(["NetworkManager: 对等体连接，ID: ", peer_id])
	var new_user = User.new()
	new_user.id = peer_id
	users[peer_id] = new_user
	peer_connected.emit(peer_id)

func _on_multiplayer_peer_disconnected(peer_id: int) -> void:
	GlobalConsole._print(["NetworkManager: 对等体断开连接，ID: ", peer_id])
	users.erase(peer_id)
	peer_disconnected.emit(peer_id)
