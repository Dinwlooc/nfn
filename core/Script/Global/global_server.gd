extends Node
#GlobalServer.gd。管理全部rpc和数据转发。
var server = WebSocketMultiplayerPeer.new()
var users:Array[User]
var url:String
var id:int = -1
signal peer_update(peer_id:int)
enum PackKey{URL}

func _ready()->void:
		multiplayer.peer_connected.connect(_peer_connected)
		multiplayer.peer_disconnected.connect(_peer_disconnected)
		multiplayer.connected_to_server.connect(_connected_to_server)
		multiplayer.server_disconnected.connect(_server_disconnected)
	

func _process(delta)->void:
	if Engine.get_process_frames() % 5 == 0:
		server.poll()
	pass

func get_id()->int:
	return id

#########

func _connected_to_server()->void:
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
func random_create()->bool:
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

func url_connect(new_url)->bool:
	if server.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		server.close()
	if server.create_client(new_url) == OK:
		GlobalConsole._print(["Client:Start to connect:",new_url])
		return true
	else :
		GlobalConsole._print("Client:Failed to connect")
		pass
		return false

func close()->void:
	server.close()
	users = []
	id = 0
	
 ###########
# 序列化方法：将数据打包为二进制
func pack_server() -> PackedByteArray:
	var data_dict :Dictionary= {
	PackKey.URL:url,
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
	url = data_dict[PackKey.URL]
	return self

func serialize_cards(cards:Array[Card])-> PackedByteArray:
	return var_to_bytes(cards.map(func(card):return card.serialize()))
	
func deserialize_cards(serialized_data: PackedByteArray)->Array[Array]:
	var card_data_array:Array[Array]
	card_data_array.append_array(bytes_to_var(serialized_data).map(Card.deserialize))
	if not card_data_array is Array[Array]:
		push_error("Invalid data format: Expected Array[Dictionary]")
		return [[]]
	return card_data_array

func cards_add_rpc(area: Area, cards: Array[Card])->void:
	var data = serialize_cards(cards)
	rpc_id(area.player.id, &"cards_add_receive", area.area_name, data)

func cards_change_rpc(area: Area, cards: Array[Card])->void:
	var data = serialize_cards(cards)
	rpc_id(area.player.id, &"cards_change_receive", area.area_name, data)

func cards_remove_rpc(area: Area, uids: Array[String])->void:
	rpc_id(area.player.id, &"cards_remove_receive", area.area_name, uids)

func upload_operation_event(serialized_event: PackedByteArray) -> void:
	var target = MultiplayerPeer.TARGET_PEER_SERVER
	rpc_id(target, "receive_operation_event", serialized_event,)

@rpc("any_peer", "call_local", "reliable")
func receive_operation_event(serialized_event: PackedByteArray) -> void:
	var event_dict = OperationEvent.deserialize(serialized_event)
	event_dict[OperationEvent.OpKey.PEER_ID] = get_tree().get_multiplayer().get_remote_sender_id()
	pass #字典应该传入System，以生成行为事件。待实现。
# 新增的RPC接收函数（移除原来的 cards_rpc_receive）
@rpc("authority", "call_local", "reliable")
func cards_add_receive(area_name: String, data: PackedByteArray)->void:
	if GlobalConsole.renderarea.has(area_name):
		var cards_data:Array[Array] = deserialize_cards(data)
		GlobalConsole.renderarea[area_name].cards_add(cards_data)

@rpc("authority", "call_local", "reliable")
func cards_change_receive(area_name: String, data: PackedByteArray)->void:
	if GlobalConsole.renderarea.has(area_name):
		GlobalConsole.renderarea[area_name].cards_change(deserialize_cards(data))

@rpc("authority", "call_local", "reliable")
func cards_remove_receive(area_name: String, ids: Array[String])->void:
	if GlobalConsole.renderarea.has(area_name):
		GlobalConsole.renderarea[area_name].cards_remove(ids)


@rpc("authority","call_remote")func receive_server_data(data)-> void:
		unpack_server(data)

@rpc("any_peer","call_remote")func ask_server_data(peer_id)-> void:
	if server.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		rpc_id(peer_id,"receive_server_data",pack_server())

	
static func bytes_to_PackedStringArray(data: PackedByteArray) -> PackedStringArray:
	var result := PackedStringArray()
	var start_idx := 0
	var end_idx := 0
	while end_idx < data.size():
		while end_idx < data.size() and data[end_idx] != 0:
			end_idx += 1
		result.append(data.slice(start_idx, end_idx).get_string_from_utf8())
		end_idx += 1
		start_idx = end_idx
	return result

# 新增：ASCII编码方法 (PackedStringArray -> PackedByteArray)
static func PackedStringArray_to_bytes_ascii(strings: PackedStringArray) -> PackedByteArray:
	var result = PackedByteArray()
	for s in strings:
		var ascii_bytes = s.to_ascii_buffer()
		result.append_array(ascii_bytes)
		result.append(0)  
	return result

# 新增：ASCII解码方法 (PackedByteArray -> PackedStringArray)
static func bytes_to_PackedStringArray_ascii(data: PackedByteArray) -> PackedStringArray:
	if data.is_empty():
		return PackedStringArray()
	var count:= 0
	for byte in data:
		if byte == 0:
			count += 1  # 每个0都标记一个字符串结束
	var result := PackedStringArray()
	result.resize(count)
	var start_idx := 0
	var end_idx := 0
	var current_index := 0 
	while end_idx < data.size():
		while end_idx < data.size() and data[end_idx] != 0:
			end_idx += 1
		var byte_slice := data.slice(start_idx, end_idx)
		result.set(current_index, byte_slice.get_string_from_ascii())
		current_index += 1
		if end_idx < data.size() and data[end_idx] == 0:
			end_idx += 1  # 跳过0字节
		start_idx = end_idx  # 移动起始位置
	return result
