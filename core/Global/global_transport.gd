## 传输层节点，负责管理网络连接与请求分发
extends Node
class_name Transport

signal render_request_received(request: RenderRequest)
signal operation_request_received(op: OperationRequest)
signal peer_update(peer_id: int)

const POLL_FRAME_INTERVAL: int = 6            ## 每隔多少帧轮询一次（60fps 下约 10 次/秒）

var network_manager: NetworkManager

func _ready() -> void:
	network_manager = NetworkManager.new()
	network_manager.set_multiplayer(multiplayer)
	GlobalConsole.c_connect_to.connect(_on_console_connect_to)
	GlobalConsole.c_close.connect(_on_console_close)

func _process(_delta: float) -> void:
	if not network_manager:
		return
	if Engine.get_process_frames() % POLL_FRAME_INTERVAL != 0:
		return
	network_manager.poll()

## 控制台命令：连接到指定 URL
func _on_console_connect_to(new_url: String) -> void:
	network_manager.url_connect(new_url)

## 控制台命令：关闭当前连接
func _on_console_close() -> void:
	network_manager.close()

## 发送渲染请求（本地延迟，远程 RPC）
func send_render_request(peer_id: int, request: RenderRequest) -> void:
	# 本地请求直接发射信号
	if peer_id == multiplayer.get_unique_id():
		call_deferred(&"_emit_render_request_local", request)
		return
	var data: PackedByteArray = RenderRequestSerializer.serialize(request)
	if peer_id == 0:
		call_deferred(&"_emit_render_request_local", request)
		rpc_id(0, &"receive_render_request", data)
		return
	if peer_id > 0:
		rpc_id(peer_id, &"receive_render_request", data)
		return
	var exclude_id: int = -peer_id
	for id: int in multiplayer.get_peers():
		if id != exclude_id:
			rpc_id(id, &"receive_render_request", data)

func _emit_render_request_local(request: RenderRequest) -> void:
	render_request_received.emit(request)

@rpc("authority", "call_remote", "reliable")
func receive_render_request(serialized_request: PackedByteArray) -> void:
	var request: RenderRequest = RenderRequestSerializer.deserialize(serialized_request)
	if not request:
		push_error("Failed to deserialize render request")
		return
	call_deferred(&"_emit_render_request_local", request)

## 上传操作请求（本地延迟，远程 RPC）
func upload_operation_request(op: OperationRequest) -> void:
	var target: int = MultiplayerPeer.TARGET_PEER_SERVER
	if multiplayer.get_unique_id() == 1:
		op.source_peer_id = multiplayer.get_unique_id()
		call_deferred(&"_emit_operation_request_local", op)
	else:
		rpc_id(target, &"receive_operation_request", OperationRequestSerializer.serialize(op))

func _emit_operation_request_local(op: OperationRequest) -> void:
	operation_request_received.emit(op)

@rpc("any_peer", "call_remote", "reliable")
func receive_operation_request(data: PackedByteArray) -> void:
	var op: OperationRequest = OperationRequestSerializer.deserialize(data)
	if op:
		op.source_peer_id = multiplayer.get_remote_sender_id()
		call_deferred(&"_emit_operation_request_local", op)
	else:
		push_error("Failed to deserialize operation request")

func start_server() -> void:
	network_manager.random_create()
