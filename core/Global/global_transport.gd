extends Node
class_name Transport

signal render_request_received(request: RenderRequest)
signal operation_request_received(op: OperationRequest)
signal peer_update(peer_id: int)

var network_manager: NetworkManager

func _ready() -> void:
	network_manager = NetworkManager.new()
	network_manager.set_multiplayer(multiplayer)
	GlobalConsole.c_connect_to.connect(_on_console_connect_to)
	GlobalConsole.c_close.connect(_on_console_close)

func _process(delta: float) -> void:
	network_manager.poll()
# 控制台命令处理
func _on_console_connect_to(new_url: String) -> void:
	network_manager.url_connect(new_url)

func _on_console_close() -> void:
	network_manager.close()

func send_render_request(peer_id: int, request: RenderRequest) -> void:
	if peer_id < 0:
		return
	rpc_id(peer_id, &"receive_render_request", RenderRequestSerializer.serialize(request))

@rpc("authority", "call_local", "reliable")
func receive_render_request(serialized_request: PackedByteArray) -> void:
	var request = RenderRequestSerializer.deserialize(serialized_request)
	if !request:
		push_error("Failed to deserialize render request")
		return
	render_request_received.emit(request)

func upload_operation_request(op: OperationRequest) -> void:
	var target = MultiplayerPeer.TARGET_PEER_SERVER
	rpc_id(target, &"receive_operation_request", OperationRequestSerializer.serialize(op))

@rpc("any_peer", "call_local", "reliable")
func receive_operation_request(data: PackedByteArray) -> void:
	var op: OperationRequest = OperationRequestSerializer.deserialize(data)
	if op:
		op.source_peer_id = multiplayer.get_remote_sender_id()
		operation_request_received.emit(op)
	else:
		push_error("Failed to deserialize operation request")
