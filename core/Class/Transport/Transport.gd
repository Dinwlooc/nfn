## 传输层服务：序列化、收发与分发请求；不含节点生命周期，多人环境由宿主节点提供。
extends RefCounted
class_name Transport
#==signals==
## 本地化后的渲染请求（已反序列化，待渲染层消费） @emitter
signal render_request_received(request: RenderRequest)
## 本地化后的操作请求（已反序列化，待系统层消费） @emitter
signal operation_request_received(op: OperationRequest)
## 对等体变更通知（预留，当前无发射点）
signal peer_update(peer_id: int)
#==vars==
## 网络管理器实例，由宿主节点创建后注入
var network_manager: NetworkManager
## 宿主节点：提供 rpc_id 与 multiplayer
var _host: Node
#==public methods==
## 绑定宿主节点与网络管理器
func _init(host_node: Node, manager: NetworkManager) -> void:
	_host = host_node
	network_manager = manager
## 发送渲染请求，自动处理本地与远程调用 @side_effect
func send_render_request(peer_id: int, request: RenderRequest) -> void:
	var data: PackedByteArray = RenderRequestSerializer.serialize(request)
	if peer_id >= 0:
		# 广播：所有对等体（包括本地）都会收到
		_host.rpc_id(0, &"receive_render_request", data)
		return
	# 排除模式：向除 -peer_id 外的所有远程对等体发送，本地不自动执行
	var exclude_id: int = -peer_id
	for id: int in _host.multiplayer.get_peers():
		if id != exclude_id:
			_host.rpc_id(id, &"receive_render_request", data)
## 反序列化远端渲染请求，延迟转发到本地信号 @delegates(_emit_render_request_local)
func handle_render_request(serialized_request: PackedByteArray) -> void:
	var request: RenderRequest = RenderRequestSerializer.deserialize(serialized_request)
	if not request:
		push_error("Failed to deserialize render request")
		return
	call_deferred(&"_emit_render_request_local", request)
## 上传操作请求，本地服务器自动转为本地调用 @side_effect
func upload_operation_request(op: OperationRequest) -> void:
	var data: PackedByteArray = OperationRequestSerializer.serialize(op)
	# 始终向服务器（ID=1）发送，若本地就是服务器则自动本地调用
	_host.rpc_id(1, &"receive_operation_request", data)
## 反序列化远端操作请求，记录来源 peer_id 后延迟转发 @delegates(_emit_operation_request_local)
func handle_operation_request(data: PackedByteArray) -> void:
	var op: OperationRequest = OperationRequestSerializer.deserialize(data)
	if not op:
		push_error("Failed to deserialize operation request")
		return
	op.source_peer_id = _host.multiplayer.get_remote_sender_id()
	call_deferred(&"_emit_operation_request_local", op)
## 启动本地服务器，port 为 0 时随机；启动失败时在控制台报错 @delegates(network_manager.create_server)
func start_server(port: int = 0) -> void:
	if network_manager.create_server(port):
		return
	GlobalConsole._print("Transport:Error:服务器启动失败，端口 %d 不可用" % port)
## 连接到指定 URL @delegates(network_manager.url_connect)
func connect_to(new_url: String) -> void:
	network_manager.url_connect(new_url)
## 关闭当前连接 @delegates(network_manager.close)
func close() -> void:
	network_manager.close()
#==private methods==
## 在本进程内转发渲染请求，call_deferred 的落点 @emitter
func _emit_render_request_local(request: RenderRequest) -> void:
	render_request_received.emit(request)
## 在本进程内转发操作请求，call_deferred 的落点 @emitter
func _emit_operation_request_local(op: OperationRequest) -> void:
	operation_request_received.emit(op)
