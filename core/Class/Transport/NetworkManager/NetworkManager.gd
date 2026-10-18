## 网络管理器，封装 WebSocket 连接生命周期与状态管理
extends RefCounted
class_name NetworkManager

## 连接状态
enum ConnectionState { DISCONNECTED, CONNECTING, CONNECTED }

## 底层 WebSocket 对等体
var peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
## 在线对等体表（peer_id → User）
var users: Dictionary[int, User] = {}        ## 对等体 ID 到 User 实例的映射
## 服务器地址（ws://…）
var url: String = ""
## 当前连接状态
var connection_state: ConnectionState = ConnectionState.DISCONNECTED
## 绑定的 MultiplayerAPI
var multiplayer_api: MultiplayerAPI

## 对等体已连接
## @emitter
signal peer_connected(peer_id: int)
## 对等体已断开
## @emitter
signal peer_disconnected(peer_id: int)
## 连接成功
## @emitter
signal connection_succeeded()
## 连接失败
## @emitter
signal connection_failed()
## 连接已关闭
## @emitter
signal connection_closed()

## 绑定 MultiplayerAPI，并接入其连接生命周期信号
## @side_effect
func set_multiplayer(multiplayer: MultiplayerAPI) -> void:
	multiplayer_api = multiplayer
	multiplayer.connected_to_server.connect(_on_multiplayer_connected_to_server)
	multiplayer.connection_failed.connect(_on_multiplayer_connection_failed)
	multiplayer.server_disconnected.connect(_on_multiplayer_server_disconnected)
	multiplayer.peer_connected.connect(_on_multiplayer_peer_connected)
	multiplayer.peer_disconnected.connect(_on_multiplayer_peer_disconnected)

## 构造：打印初始化完成
func _init() -> void:
	GlobalConsole._print("NetworkManager: 网络管理器初始化完成")

## 轮询网络事件（仅在连接活跃时执行）
func poll() -> void:
	if connection_state == ConnectionState.DISCONNECTED:
		return
	if connection_state == ConnectionState.CONNECTING:
		var status: int = peer.get_connection_status()
		if status == MultiplayerPeer.CONNECTION_CONNECTED:
			connection_state = ConnectionState.CONNECTED
			GlobalConsole._print("NetworkManager: 连接成功")
			connection_succeeded.emit()
		elif status == MultiplayerPeer.CONNECTION_DISCONNECTED:
			connection_state = ConnectionState.DISCONNECTED
			GlobalConsole._print("NetworkManager: 连接失败")
			connection_failed.emit()
	peer.poll()

## 获取当前对等体 ID（若未连接返回 -1）
func get_current_id() -> int:
	if peer and peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		return peer.get_unique_id()
	return -1

## 启动服务器（随机端口）
func random_create() -> bool:
	var port: int = randi_range(1024, 65535)
	if peer.create_server(port) != OK:
		return false
	url = "ws://localhost:" + str(port)
	connection_state = ConnectionState.CONNECTED
	var current_id: int = get_current_id()
	if current_id != -1:
		var user: User = User.new()
		user.id = current_id
		user.get_config()
		users[current_id] = user
		peer_connected.emit(current_id)
	GlobalConsole._print(["NetworkManager: 服务器成功启动:ws://localhost:", port])
	multiplayer_api.multiplayer_peer = peer
	connection_succeeded.emit()
	return true

## 客户端连接
func url_connect(new_url: String) -> bool:
	if connection_state != ConnectionState.DISCONNECTED:
		close()
	GlobalConsole._print(["NetworkManager: 尝试连接到: ", new_url])
	if peer.create_client(new_url) == OK:
		connection_state = ConnectionState.CONNECTING
		return true
	return false

## 关闭当前连接
func close() -> void:
	peer.close()
	users.clear()
	connection_state = ConnectionState.DISCONNECTED
	GlobalConsole._print("NetworkManager: 网络连接已关闭")

## 获取当前已连接用户数量
func get_user_count() -> int:
	return users.size()

## 获取底层 WebSocket 对等体实例
func get_peer() -> WebSocketMultiplayerPeer:
	return peer

# --- MultiplayerAPI 信号处理 ---
## 已连上服务器：注册自己的 User 并广播
## @emitter
func _on_multiplayer_connected_to_server() -> void:
	GlobalConsole._print("NetworkManager: 已连接到服务器")
	var current_id: int = get_current_id()
	if current_id != -1:
		var user: User = User.new()
		user.id = current_id
		user.get_config()
		users[current_id] = user
		peer_connected.emit(current_id)
		multiplayer_api.multiplayer_peer = peer

## 连接失败回调
## @emitter
func _on_multiplayer_connection_failed() -> void:
	GlobalConsole._print("NetworkManager: 连接失败")
	connection_state = ConnectionState.DISCONNECTED
	connection_failed.emit()

## 服务器断开回调：清空用户表并广播
## @emitter
func _on_multiplayer_server_disconnected() -> void:
	GlobalConsole._print("NetworkManager: 服务器断开连接")
	connection_state = ConnectionState.DISCONNECTED
	users.clear()
	connection_closed.emit()

## 新对等体连接回调：登记 User 并广播
## @emitter
func _on_multiplayer_peer_connected(peer_id: int) -> void:
	GlobalConsole._print(["NetworkManager: 对等体连接，ID: ", peer_id])
	var new_user: User = User.new()
	new_user.id = peer_id
	users[peer_id] = new_user
	peer_connected.emit(peer_id)

## 对等体断开回调：移除 User 并广播
## @emitter
func _on_multiplayer_peer_disconnected(peer_id: int) -> void:
	GlobalConsole._print(["NetworkManager: 对等体断开连接，ID: ", peer_id])
	users.erase(peer_id)
	peer_disconnected.emit(peer_id)
