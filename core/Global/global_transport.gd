extends Node
#GlobalTransport.gd。管理全部rpc和数据转发。
const CardData = RenderPack.CardData

func serialize_cards(cards:Array[Card])-> PackedByteArray:
	return var_to_bytes(cards.map(func(card):return card.serialize()))
	
func deserialize_cards(serialized_data: PackedByteArray)->Array[CardData]:
	var card_data_array:Array[CardData]
	card_data_array.append_array(bytes_to_var(serialized_data).map(CardSerializer.deserialize))
	return card_data_array

func cards_add_rpc(area: Area, cards: Array[Card])->void:
	var data = serialize_cards(cards)
	rpc_id(area.player.id, &"cards_add_receive", area.area_name, data)

func cards_change_rpc(area: Area, cards: Array[Card])->void:
	var data = serialize_cards(cards)
	rpc_id(area.player.id, &"cards_change_receive", area.area_name, data)

func cards_remove_rpc(area: Area, uids: Array[String])->void:
	rpc_id(area.player.id, &"cards_remove_receive", area.area_name, uids)

func upload_operation_request(op: OperationRequest) -> void:
	var target = MultiplayerPeer.TARGET_PEER_SERVER
	rpc_id(target, &"receive_operation_event", op.serialize())

@rpc("any_peer", "call_local", "reliable")
func receive_operation_request(data: PackedByteArray) -> void:
	var op:OperationRequest = OperationRequest.deserialize(data)
	pass #待实现。

@rpc("authority", "call_local", "reliable")
func cards_add_receive(area_name: String, data: PackedByteArray)->void:
	var _area_name:= StringName(area_name)
	if GlobalRegistry.renderarea.has(_area_name):
		var cards_data:Array[CardData] = deserialize_cards(data)
		GlobalRegistry.renderarea[area_name].cards_add(cards_data)

@rpc("authority", "call_local", "reliable")
func cards_change_receive(area_name: String, data: PackedByteArray)->void:
	if GlobalRegistry.renderarea.has(area_name):
		GlobalRegistry.renderarea[area_name].cards_change(deserialize_cards(data))

@rpc("authority", "call_local", "reliable")
func cards_remove_receive(area_name: String, ids: Array[String])->void:
	if GlobalRegistry.renderarea.has(area_name):
		GlobalRegistry.renderarea[area_name].cards_remove(ids)

@rpc("authority", "call_remote")
func receive_server_data(data: PackedByteArray) -> void:
	var network_data = NetworkSerializer.deserialize(data)
	# 处理接收到的网络数据
	print("Received server data: ", network_data)

@rpc("any_peer", "call_remote")
func ask_server_data(peer_id: int) -> void:
	var network_manager = GlobalRegistry.get_network_manager()
	if network_manager.server.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		var packed_data = NetworkSerializer.serialize(network_manager)
		rpc_id(peer_id, &"receive_server_data", packed_data)
