extends Node
class_name NetworkManager

var server = WebSocketMultiplayerPeer.new()
var users:Array[User]
var url:String
var id:int = -1
signal peer_update(peer_id:int)

func _ready()->void:
		signal_connect_test()
		multiplayer.peer_connected.connect(_peer_connected)
		multiplayer.peer_disconnected.connect(_peer_disconnected)
		multiplayer.connected_to_server.connect(_connected_to_server)
		multiplayer.server_disconnected.connect(_server_disconnected)
		GlobalRegistry.register_singleton(GlobalRegistry.NETWORK_MANAGER_TYPE,self)
		random_create()
		get_multiplayer().multiplayer_peer = server

func _process(delta)->void:
	if Engine.get_process_frames() % 5 == 0:
		server.poll()
	pass

func get_id()->int:
	return id
#########
func _connected_to_server()->void:
	id = server.get_unique_id()
	GlobalConsole._print(["Server:服务器已经连接。你的ID： ",id])
	emit_signal(&"peer_update",id)
	rpc_id(1,&"ask_server_data",id)
	pass
	
func _server_disconnected():
	GlobalConsole._print("Server:您已断连。")
	pass
	
func _peer_connected(new_id)-> void:
	if new_id == id:
		return
	GlobalConsole._print(["Server:玩家接入，ID: ", new_id])
	# 创建一个新的用户实例并添加到 uers 数组
	var new_user = User.new()
	new_user.id = new_id
	users.append(new_user)
	# 打印当前所有玩家及其序号
	GlobalConsole._print("Server:当前房间内的玩家有：")
	for i in range(0,users.size()):
		GlobalConsole._print([users[i].name,"ID：",users[i].id])
	pass
	
func _peer_disconnected(new_id)-> void:
	if new_id == id:
		return
	GlobalConsole._print(["Server:玩家断离，ID: ", new_id])
	users = users.filter(func(player):return (player.id != new_id))
	pass
######
func random_create()->bool:
	var port = randi_range(1024,65535)
	if server.create_server(port) == OK:
		id = 1
		url = "ws://localhost:"+str(port)
		GlobalConsole._print(["Server:服务器创建于: ",url,"。ID:",server.get_unique_id()])
		var user = User.new()
		user.id = 1
		user.get_config()
		users.append(user)
		return true
	else:
		print("Server:服务器创建失败")
		return false

func url_connect(new_url)->bool:
	if server.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		server.close()
	if server.create_client(new_url) == OK:
		GlobalConsole._print(["Client:开始连接:",new_url])
		return true
	else :
		GlobalConsole._print("Client:连接失败")
		pass
		return false

func close()->void:
	server.close()
	users = []
	id = 0
 ###########
func get_network_data()->NetworkManager:
	return self

func _connect_to(new_url:String):
	if id == 1:
		GlobalConsole._print("MainGame:c_connerct_to未执行：服务器端请先使用c_close()关闭服务器。")
		return
	if new_url == "0":
		url_connect(url)
		return
	else:
		url_connect(new_url)
		return

func _close():
	if id == 1:
		GlobalConsole._print("MainGame:服务器已关闭。")
	else:
		GlobalConsole._print("MainGame:客户端已关闭。")
	close()
	
func signal_connect_test():
	GlobalConsole.c_connect_to.connect(_connect_to)
	GlobalConsole.c_close.connect(_close)
