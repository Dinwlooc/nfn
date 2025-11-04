extends Node
class_name NetworkManager

var server = WebSocketMultiplayerPeer.new()
var users:Array[User]
var url:String
var id:int = -1
signal peer_update(peer_id:int)

func _ready()->void:
	GlobalConsole._print("NetworkManager: 网络管理器初始化完成")  # 添加初始化日志
	signal_connect_test()
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server)
	multiplayer.server_disconnected.connect(_server_disconnected)
	GlobalRegistry.register_singleton(GlobalRegistry.NETWORK_MANAGER_TYPE,self)
	call_deferred(&"random_create")

func _process(delta)->void:
	if Engine.get_process_frames() % 5 == 0:
		server.poll()

func get_id()->int:
	return id

func _connected_to_server()->void:
	id = server.get_unique_id()
	GlobalConsole._print(["Client: 成功连接服务器，分配客户端ID: ", id])  # 客户端连接成功日志
	emit_signal(&"peer_update",id)
	rpc_id(1,&"ask_server_data",id)
	
func _server_disconnected():
	GlobalConsole._print("Client: 与服务器的连接已断开")  # 客户端断开日志
	
func _peer_connected(new_id)-> void:
	if new_id == id:
		return
	GlobalConsole._print(["Server: 新客户端连接，ID: ", new_id])  # 服务端新连接日志
	var new_user = User.new()
	new_user.id = new_id
	users.append(new_user)
	
	# 记录当前连接的客户端
	GlobalConsole._print("Server: 当前连接的客户端列表:")
	for i in range(users.size()):
		GlobalConsole._print(["Server:  客户端 #", i+1, " - ID: ", users[i].id])
	
func _peer_disconnected(new_id)-> void:
	if new_id == id:
		return
	GlobalConsole._print(["Server: 客户端断开，ID: ", new_id])  # 服务端断开日志
	users = users.filter(func(player):return (player.id != new_id))
	GlobalConsole._print(["Server: 剩余客户端数量: ", users.size()])  # 更新客户端计数

func random_create()->bool:
	var port = randi_range(1024,65535)
	if server.create_server(port) == OK:
		id = 1
		url = "ws://localhost:"+str(port)
		GlobalConsole._print(["Server: 服务器成功启动，监听端口: ", port])  # 服务器启动日志
		GlobalConsole._print(["Server: 服务端URL: ", url])
		
		var user = User.new()
		user.id = 1
		user.get_config()
		users.append(user)
		get_multiplayer().multiplayer_peer = server
		return true
	else:
		GlobalConsole._print("Server: 服务器启动失败")  # 服务器启动失败日志
		return false



func url_connect(new_url)->bool:
	if server.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		server.close()
	
	GlobalConsole._print(["Client: 尝试连接到服务器: ", new_url])  # 客户端连接尝试日志
	if server.create_client(new_url) == OK:
		get_multiplayer().multiplayer_peer = server
		GlobalConsole._print(["Client: 已向服务器发起连接请求"])  # 客户端连接请求日志
		return true
	else :
		GlobalConsole._print("Client: 连接初始化失败")  # 客户端连接失败日志
		return false

func close()->void:
	server.close()
	users = []
	id = 0
	GlobalConsole._print("NetworkManager: 网络连接已关闭")  # 通用关闭日志
 
func get_network_data()->NetworkManager:
	return self

func _connect_to(new_url:String):
	if id == 1:
		GlobalConsole._print("NetworkManager: 连接请求被拒绝 - 当前处于服务器模式")  # 模式错误日志
		return
	if new_url == "0":
		url_connect(url)
	else:
		url_connect(new_url)

func _close():
	if id == 1:
		GlobalConsole._print("NetworkManager: 正在关闭服务器...")  # 服务器关闭日志
	else:
		GlobalConsole._print("NetworkManager: 正在断开客户端连接...")  # 客户端断开日志
	close()
	
func signal_connect_test():
	GlobalConsole.c_connect_to.connect(_connect_to)
	GlobalConsole.c_close.connect(_close)
