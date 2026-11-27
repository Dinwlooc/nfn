## 传输层单例节点：管理网络生命周期（建管理器、轮询、控制台接线），传输语义委托给 Transport 服务。
extends Node
#==consts==
## 网络轮询间隔（帧）
const POLL_FRAME_INTERVAL: int = 6
#==vars==
## 网络管理器实例，实例化时创建
var network_manager: NetworkManager
## 传输服务，实例化时创建；对外类型为 Transport
var transport: Transport
#==public methods==
## 实例化时就建好管理器与服务，场景在 _ready 前读到的不是空引用 @delegates(Transport.new)
func _init() -> void:
	network_manager = NetworkManager.new()
	transport = Transport.new(self, network_manager)
## 接线多人环境与控制台命令
func _ready() -> void:
	network_manager.set_multiplayer(multiplayer)
	GlobalConsole.c_connect_to.connect(_on_c_connect_to)
	GlobalConsole.c_close.connect(_on_c_close)
## 按 POLL_FRAME_INTERVAL 节流轮询网络事件 @delegates(network_manager.poll)
func _process(_delta: float) -> void:
	if not network_manager:
		return
	if Engine.get_process_frames() % POLL_FRAME_INTERVAL != 0:
		return
	network_manager.poll()
## 发送渲染请求，转发到传输服务 @delegates(transport.send_render_request)
func send_render_request(peer_id: int, request: RenderRequest) -> void:
	transport.send_render_request(peer_id, request)
## 上传操作请求，转发到传输服务 @delegates(transport.upload_operation_request)
func upload_operation_request(op: OperationRequest) -> void:
	transport.upload_operation_request(op)
## 启动本地服务器，转发到传输服务 @delegates(transport.start_server)
func start_server(port: int = 0) -> void:
	transport.start_server(port)
## RPC 入口：远端渲染请求交给传输服务分发 @delegates(transport.handle_render_request)
@rpc("authority", "call_local", "reliable")
func receive_render_request(serialized_request: PackedByteArray) -> void:
	transport.handle_render_request(serialized_request)
## RPC 入口：远端操作请求交给传输服务分发 @delegates(transport.handle_operation_request)
@rpc("any_peer", "call_local", "reliable")
func receive_operation_request(data: PackedByteArray) -> void:
	transport.handle_operation_request(data)
#==private methods==
## 控制台命令：连接到指定 URL @delegates(transport.connect_to)
func _on_c_connect_to(new_url: String) -> void:
	transport.connect_to(new_url)
## 控制台命令：关闭当前连接 @delegates(transport.close)
func _on_c_close() -> void:
	transport.close()
