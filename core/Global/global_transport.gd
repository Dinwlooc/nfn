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

func _process(_delta: float) -> void:
	if network_manager:
		network_manager.poll()

# 控制台命令处理
func _on_console_connect_to(new_url: String) -> void:
	network_manager.url_connect(new_url)
	set_process(true)

func _on_console_close() -> void:
	network_manager.close()

## 发送渲染请求（本地延迟，远程RPC）
func send_render_request(peer_id: int, request: RenderRequest) -> void:
	if peer_id < 0:
		return
	if peer_id == multiplayer.get_unique_id():
		call_deferred(&"_emit_render_request_local", request)
	else:
		rpc_id(peer_id, &"receive_render_request", RenderRequestSerializer.serialize(request))

func _emit_render_request_local(request: RenderRequest) -> void:
	render_request_received.emit(request)

@rpc("authority", "call_local", "reliable")
func receive_render_request(serialized_request: PackedByteArray) -> void:
	var request = RenderRequestSerializer.deserialize(serialized_request)
	if !request:
		push_error("Failed to deserialize render request")
		return
	# 远程请求也延迟发射（可选，通常网络延迟已足够，这里统一延迟以保持平滑）
	call_deferred(&"_emit_render_request_local", request)

## 上传操作请求（本地延迟，远程RPC）
func upload_operation_request(op: OperationRequest) -> void:
	var target = MultiplayerPeer.TARGET_PEER_SERVER
	# 如果是本地服务器玩家自己，延迟发射信号
	if multiplayer.get_unique_id() == 1:  # 假设服务器自身 peer_id 为 1，或根据实际判断
		# 本地请求需要手动设置 source_peer_id
		op.source_peer_id = multiplayer.get_unique_id()
		call_deferred(&"_emit_operation_request_local", op)
	else:
		rpc_id(target, &"receive_operation_request", OperationRequestSerializer.serialize(op))

## 本地延迟发射操作请求信号
func _emit_operation_request_local(op: OperationRequest) -> void:
	operation_request_received.emit(op)

@rpc("any_peer", "call_local", "reliable")
func receive_operation_request(data: PackedByteArray) -> void:
	var op: OperationRequest = OperationRequestSerializer.deserialize(data)
	if op:
		op.source_peer_id = multiplayer.get_remote_sender_id()
		# 延迟发射，避免阻塞 RPC 回调
		call_deferred(&"_emit_operation_request_local", op)
	else:
		push_error("Failed to deserialize operation request")

func start_server() -> void:
	network_manager.random_create()
