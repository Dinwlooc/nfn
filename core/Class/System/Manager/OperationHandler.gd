## 操作请求处理器，负责验证请求、管理请求槽位与响应权。
extends RefCounted
class_name OperationHandler

#=== Variables ===
var _peer_player_map: Dictionary[int, int] = {}
var _pending_requests: Dictionary[int, OperationRequest] = {}
var _null_request: OperationRequest = OperationRequest.new()

#=== Signals ===
## 操作验证通过信号
## @emitter
signal operation_validated(request: OperationRequest)
## 可响应的玩家 ID 列表更新信号
## @emitter
signal permissions_updated(responsive_player_ids: PackedInt32Array)

#=== Enums ===
enum RequestState { CANCELLED, COMPLETED }

#=== Public Methods ===
## 更新对等端到玩家 ID 的映射
## @endo
func update_verification_mapping(peer_id: int, player_id: int) -> void:
	_peer_player_map[peer_id] = player_id
## 验证请求来源是否合法
## @pure
func verify_operation(request: OperationRequest) -> bool:
	if request == _null_request:
		return false
	if request.source_peer_id == -1:
		return true
	var source_player_id = _peer_player_map.get(request.source_peer_id, -1)
	return source_player_id == request.source_player_id
## 处理请求（验证并分发）
## @endo @emitter
func handle_request(request: OperationRequest) -> void:
	GlobalConsole._print(["OperationHandler:接受到请求：", request.get_class_name()])
	if not verify_operation(request):
		GlobalConsole._print(["OperationHandler:取消请求：", request.get_class_name(), "。原因：访问了不合法的玩家"])
		return
	var player_id: int = request.source_player_id
	if not _can_accept_new_request(player_id):
		GlobalConsole._print(["OperationHandler:取消请求：", request.get_class_name(), "。原因：玩家无响应权"])
		return
	_setup_request_tracking(player_id, request)
	operation_validated.emit(request)
## 设置玩家响应状态（启用/禁用）
## @endo @emitter
func set_player_responsive(player_id: int, can_respond: bool) -> void:
	if can_respond:
		_enable_player_response(player_id)
	else:
		_disable_player_response(player_id)
	permissions_updated.emit(_get_responsive_player_ids())
## 批量设置响应玩家
## @endo @emitter
func set_responsive_players(player_ids: PackedInt32Array) -> void:
	var current_players = _pending_requests.keys().duplicate()
	for pid in current_players:
		_disable_player_response(pid)
	for pid in player_ids:
		_enable_player_response(pid)
	permissions_updated.emit(_get_responsive_player_ids())
## 检查玩家是否有待处理请求
## @pure
func has_pending_request(player_id: int) -> bool:
	var req = _pending_requests.get(player_id, _null_request)
	return req != _null_request
## 检查玩家是否当前可以响应（即槽位为 _null_request）
## @pure
func is_player_responsive(player_id: int) -> bool:
	return _pending_requests.get(player_id, null) == _null_request
## 获取玩家的当前请求（若槽位是 _null_request 则返回 null）
## @pure
func get_player_request(player_id: int) -> OperationRequest:
	var request = _pending_requests.get(player_id, null)
	if request == _null_request:
		return null
	return request

#=== Private Methods ===
## 检查玩家是否可以接受新请求
## @pure
func _can_accept_new_request(player_id: int) -> bool:
	return _pending_requests.get(player_id) == _null_request
## 设置请求跟踪（连接信号）
## @endo @signal-listener
func _setup_request_tracking(player_id: int, request: OperationRequest) -> void:
	_pending_requests[player_id] = request
	request.cancelled.connect(_on_request_cancelled.bind(request))
	request.completed.connect(_on_request_completed.bind(request))
## 请求取消回调
## @endo @signal-listener
func _on_request_cancelled(request: OperationRequest) -> void:
	_cleanup_request(request.source_player_id)
	GlobalConsole._print(["请求取消，玩家ID：%d" % request.source_player_id])
## 请求完成回调
## @signal-listener
func _on_request_completed(request: OperationRequest) -> void:
	GlobalConsole._print(["请求处理完成，玩家ID：%d，等待响应权重新授予" % request.source_player_id])
## 清理请求槽位（重置为 _null_request）
## @endo
func _cleanup_request(player_id: int) -> void:
	if not _pending_requests.has(player_id):
		return
	var request: OperationRequest = _pending_requests[player_id]
	if request == _null_request:
		return
	if request.state == OperationRequest.State.PROCESS:
		request.cancel()
	_disconnect_request_signals(request)
	_pending_requests[player_id] = _null_request
## 断开请求信号连接
## @signal-listener
func _disconnect_request_signals(request: OperationRequest) -> void:
	request.cancelled.disconnect(_on_request_cancelled)
	request.completed.disconnect(_on_request_completed)
## 启用玩家响应权
## @endo
func _enable_player_response(player_id: int) -> void:
	if not _pending_requests.has(player_id):
		_pending_requests[player_id] = _null_request
		return
	var current = _pending_requests[player_id]
	if current != _null_request:
		_cleanup_request(player_id)
## 禁用玩家响应权
## @endo
func _disable_player_response(player_id: int) -> void:
	if not _pending_requests.has(player_id):
		return
	var request = _pending_requests[player_id]
	if request != _null_request:
		_cleanup_request(player_id)
	_pending_requests.erase(player_id)
## 获取当前可响应的玩家 ID 列表
## @pure
func _get_responsive_player_ids() -> PackedInt32Array:
	var ids: PackedInt32Array = []
	for player_id in _pending_requests:
		if _pending_requests[player_id] == _null_request:
			ids.append(player_id)
	return ids
