extends Node
#GlobalServer.gd。管理全部rpc和数据转发。
var server = WebSocketMultiplayerPeer.new()
var users:Array[User]
var url:String
var server_status:int
var status:int 
var id:int
signal peer_update(peer_id:int)

func _ready():
		multiplayer.peer_connected.connect(_peer_connected)
		multiplayer.peer_disconnected.connect(_peer_disconnected)
		multiplayer.connected_to_server.connect(_connected_to_server)
		multiplayer.server_disconnected.connect(_server_disconnected)
	

func _process(delta):
	if Engine.get_process_frames() % 5 == 0:
		server.poll()
		status = server.get_connection_status()
	pass

#########

func _connected_to_server():
	id = server.get_unique_id()
	GlobalConsole._print(["服务器已经连接。你的ID： ",id])
	emit_signal("peer_update",id)
	rpc_id(1,"ask_server_data",id)
	pass
	
func _server_disconnected():
	GlobalConsole._print("您已断连。")
	pass
	
func _peer_connected(new_id)-> void:
	if new_id == id:
		return
	GlobalConsole._print(["Server:Player connected with ID: ", new_id])
	# 创建一个新的用户实例并添加到 uers 数组
	var new_user = User.new()
	new_user.id = new_id
	users.append(new_user)
	# 打印当前所有玩家及其序号
	GlobalConsole._print("当前房间内的玩家有：")
	for i in range(0,users.size()):
		GlobalConsole._print([users[i].name,"ID：",users[i].id])
	pass
	
func _peer_disconnected(new_id)-> void:
	if new_id == id:
		return
	GlobalConsole._print(["Server:Player disconnected with ID: ", new_id])
	users = users.filter(func(player):return (player.id != new_id))
	pass
######
func random_create():
	var port = randi_range(1024,65535)
	if server.create_server(port) == OK:
		id = 1
		url = "ws://localhost:"+str(port)
		GlobalConsole._print(["Server:Server created on: ",url,"。ID:",server.get_unique_id()])
		var user = User.new()
		user.id = 1
		user.get_config()
		users.append(user)
		return true
	else:
		print("Server:Server creation failed")
		return false

func url_connect(new_url):
	if status == MultiplayerPeer.CONNECTION_CONNECTED:
		server.close()
	if server.create_client(new_url) == OK:
		GlobalConsole._print(["Client:Start to connect:",new_url])
		return true
	else :
		GlobalConsole._print("Client:Failed to connect")
		pass
		return false

func cconnect_status():
	if status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return("Client:Missing\n")
	if status == MultiplayerPeer.CONNECTION_CONNECTING:
		return("Client:Connecting\n")
	if status == MultiplayerPeer.CONNECTION_CONNECTED:
		return("Client:OK\n")

func completely_close():
	server.close()
	users = []
	id = 0
	
const _PACK_WHITELIST = [
	"url"
]
 
# 序列化方法：将数据打包为二进制
func pack_server() -> PackedByteArray:
	var data_dict :Dictionary= {
	"url":url,
	}
	return var_to_bytes(data_dict)  # Godot内置序列化方法
 
# 反序列化方法：从二进制还原数据
func unpack_server(bytes: PackedByteArray):
	var data_dict = bytes_to_var(bytes)  # 反序列化字典
	# 验证数据有效性
	if not data_dict is Dictionary:
		push_error("Invalid data format: Expected Dictionary")
		return self
	# 按白名单顺序设置属性（保证兼容性）
	url = data_dict["url"]
	return self

func pack_card(card:Card) -> PackedByteArray:
	var data_dict :Dictionary= {
	"name":card.name,
	"real_name":card.real_name,
	"description":card.description,
	"type":card.type,
	"suit":card.suit,
	"basic_damage":card.basic_damage,
	"basic_cost":card.basic_cost,
	}
	return var_to_bytes(data_dict)  # Godot内置序列化方法
	
func unpack_card(bytes: PackedByteArray)->Dictionary:
	var data_dict = bytes_to_var(bytes)  # 反序列化字典
	# 验证数据有效性
	if not data_dict is Dictionary:
		push_error("Invalid data format: Expected Dictionary")
		return {}
	return data_dict

func serialize_cards(cards:Array[Card])-> PackedByteArray:
	var bytes:Array = cards.map(func(card):return pack_card(card))
	return var_to_bytes(bytes)
	
func deserialize_cards(serialized_data: PackedByteArray)->Array[Dictionary]:
	var byte:Array = bytes_to_var(serialized_data)
	var card_data_array:Array[Dictionary] = []
	card_data_array.append_array(byte.map(func(data):return unpack_card(data)))
	return card_data_array

func cards_rpc(area:Area,rpc_name:String,cards:Array[Card]):
	var data  = serialize_cards(cards)
	rpc_id(area.player.id,"cards_rpc_receive",rpc_name,area.area_name,data)

@rpc("authority","call_local") func cards_rpc_receive(rpc_name:String,area_name:String,data:PackedByteArray):
	GlobalConsole.realarea[area_name].call(rpc_name,deserialize_cards(data))
	pass

@rpc("authority","call_remote")func receive_server_data(data)-> void:
	if server.status == MultiplayerPeer.CONNECTION_CONNECTED:
		unpack_server(data)
	
@rpc("any_peer","call_remote")func ask_server_data(peer_id)-> void:
	if server.status == MultiplayerPeer.CONNECTION_CONNECTED:
		rpc_id(peer_id,"receive_server_data",pack_server())
