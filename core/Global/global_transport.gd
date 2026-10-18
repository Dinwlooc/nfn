## 传输层节点，负责管理网络连接与请求分发。
extends Node
class_name Transport

## 本地化后的渲染请求（已反序列化，待渲染层消费）
## @emitter
signal render_request_received(request: RenderRequest)
## 本地化后的操作请求（已反序列化，待系统层消费）
## @emitter
signal operation_request_received(op: OperationRequest)
## 对等体变更通知（预留，当前无发射点）
signal peer_update(peer_id: int)
## 网络轮询间隔（帧）
const POLL_FRAME_INTERVAL: int = 6            ## 每隔多少帧轮询一次（60fps 下约 10 次/秒）
## 网络管理器实例，_ready 时创建
var network_manager: NetworkManager

## 创建网络管理器并接线控制台命令
func _ready() -> void:
	network_manager = NetworkManager.new()
	network_manager.set_multiplayer(multiplayer)
	GlobalConsole.c_connect_to.connect(_on_console_connect_to)
	GlobalConsole.c_close.connect(_on_console_close)

## 按 POLL_FRAME_INTERVAL 节流轮询网络事件
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

## 发送渲染请求（自动处理本地/远程调用）
## @side_effect
func send_render_request(peer_id: int, request: RenderRequest) -> void:
	var data: PackedByteArray = RenderRequestSerializer.serialize(request)
	if peer_id >= 0:
		# 广播：所有对等体（包括本地）都会收到
		rpc_id(0, &"receive_render_request", data)
		return
	# 排除模式：向除 -peer_id 外的所有远程对等体发送（本地不自动执行）
	var exclude_id: int = -peer_id
	for id: int in multiplayer.get_peers():
		if id != exclude_id:
			rpc_id(id, &"receive_render_request", data)

## 在本进程内转发渲染请求（call_deferred 的落点）
## @emitter
func _emit_render_request_local(request: RenderRequest) -> void:
	render_request_received.emit(request)

## RPC：反序列化远端渲染请求，延迟转发到本地信号
## @delegates
@rpc("authority", "call_local", "reliable")
func receive_render_request(serialized_request: PackedByteArray) -> void:
	var request: RenderRequest = RenderRequestSerializer.deserialize(serialized_request)
	if not request:
		push_error("Failed to deserialize render request")
		return
	call_deferred(&"_emit_render_request_local", request)

## 上传操作请求（本地服务器自动转为本地调用）
## @side_effect
func upload_operation_request(op: OperationRequest) -> void:
	var data: PackedByteArray = OperationRequestSerializer.serialize(op)
	# 始终向服务器（ID=1）发送，若本地就是服务器则自动本地调用
	rpc_id(1, &"receive_operation_request", data)

## 在本进程内转发操作请求（call_deferred 的落点）
## @emitter
func _emit_operation_request_local(op: OperationRequest) -> void:
	operation_request_received.emit(op)

## RPC：反序列化远端操作请求，记录来源 peer_id 后延迟转发
## @delegates
@rpc("any_peer", "call_local", "reliable")
func receive_operation_request(data: PackedByteArray) -> void:
	var op: OperationRequest = OperationRequestSerializer.deserialize(data)
	if op:
		op.source_peer_id = multiplayer.get_remote_sender_id()
		call_deferred(&"_emit_operation_request_local", op)
	else:
		push_error("Failed to deserialize operation request")

## 以随机端口启动本地服务器
## @delegates
func start_server() -> void:
	network_manager.random_create()
