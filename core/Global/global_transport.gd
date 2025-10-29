extends Node
class_name Transport
#GlobalTransport.gd。管理全部rpc和数据转发。
var render_request_handler: RenderRequestHandler

func _ready():
	render_request_handler = RenderRequestHandler.new()

func send_render_request(player_id:int, request: RenderRequest) -> void:
	rpc_id(player_id, &"receive_render_request", RenderRequestSerializer.serialize(request))

@rpc("authority", "call_local", "reliable")
func receive_render_request(serialized_request: PackedByteArray) -> void:
	var request = RenderRequestSerializer.deserialize(serialized_request)
	if request and render_request_handler:
		render_request_handler.handle_request(request)

func upload_operation_request(op: OperationRequest) -> void:
	var target = MultiplayerPeer.TARGET_PEER_SERVER
	rpc_id(target, &"receive_operation_request", OperationRequestSerializer.serialize(op))

@rpc("any_peer", "call_local", "reliable")
func receive_operation_request(data: PackedByteArray) -> void:
	var op:OperationRequest = OperationRequestSerializer.deserialize(data)
	GlobalConsole._print("Transport:接收到操作请求。")

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
