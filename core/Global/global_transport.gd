extends Node

#GlobalTransport.gd。管理全部rpc和数据转发。

const CardData = RenderPack.CardData

func serialize_cards(cards:Array[Card])-> PackedByteArray:
	return CardSerializer.serialize_array(cards)

func deserialize_cards(serialized_data: PackedByteArray)->Array[CardData]:
	return CardSerializer.deserialize_array(serialized_data)

enum CARD_OP {ADD = 0, UPDATE = 1, REMOVE = 2}

func cards_add_rpc(area: Area, cards: Array[Card])->void:
	var data = serialize_cards(cards)
	rpc_id(area.player.id, &"cards_receive",CARD_OP.ADD,String(area.area_name), data)

func cards_change_rpc(area: Area)->void:
	pass

func cards_remove_rpc(area: Area, uids: PackedInt32Array)->void:
	rpc_id(area.player.id, &"cards_receive",CARD_OP.REMOVE,String(area.area_name), uids)

func upload_operation_request(op: OperationRequest) -> void:
	var target = MultiplayerPeer.TARGET_PEER_SERVER
	rpc_id(target, &"receive_operation_event", op.serialize())

@rpc("any_peer", "call_local", "reliable")
func receive_operation_request(data: PackedByteArray) -> void:
	var op:OperationRequest = OperationRequest.deserialize(data)
	pass #待实现。

@rpc("authority", "call_local", "reliable")
func cards_receive(card_op:CARD_OP, area_name: String,data: PackedByteArray)->void:
	var render_area:RenderArea = GlobalRegistry._renderareas.get(StringName(area_name))
	if !render_area:
		return
	match card_op:
		CARD_OP.ADD:
			var cards_data:Array[CardData] = deserialize_cards(data)
			render_area.cards_add(cards_data)
		pass

@rpc("authority", "call_remote")
func receive_server_data(data: PackedByteArray) -> void:
	var network_data = NetworkSerializer.deserialize(data)
	print("Received server data: ", network_data)

@rpc("any_peer", "call_remote")
func ask_server_data(peer_id: int) -> void:
	var network_manager = GlobalRegistry.get_network_manager()
	if network_manager.server.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		var packed_data = NetworkSerializer.serialize(network_manager)
		rpc_id(peer_id, &"receive_server_data", packed_data)
