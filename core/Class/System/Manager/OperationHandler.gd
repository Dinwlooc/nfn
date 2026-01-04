extends RefCounted
class_name OperationHandler

var _peer_player_map: Dictionary[int, int] = {}
var _pending_requests: Dictionary[int, OperationRequest] = {}
var _null_request: OperationRequest = OperationRequest.new()
signal operation_validated(request: OperationRequest)
signal permissions_updated
enum RequestState { CANCELLED, COMPLETED }

func update_verification_mapping(peer_id: int, player_id: int) -> void:
	_peer_player_map[peer_id] = player_id

func verify_operation(request: OperationRequest) -> bool:
	if request == _null_request:
		return false
	var source_player_id = _peer_player_map.get(request.source_peer_id, -1)
	return source_player_id == request.source_player_id

func handle_request(request: OperationRequest) -> void:
	if request == _null_request:
		return
	if !verify_operation(request):
		return
	var player_id = request.source_player_id
	if !_can_accept_new_request(player_id):
		return
	_setup_request_tracking(player_id, request)
	operation_validated.emit(request)

func _can_accept_new_request(player_id: int) -> bool:
	return _pending_requests.get(player_id, _null_request) == _null_request

func _setup_request_tracking(player_id: int, request: OperationRequest) -> void:
	_pending_requests[player_id] = request
	request.cancelled.connect(_on_request_cancelled.bind(request))
	request.completed.connect(_on_request_completed.bind(request))

func _on_request_cancelled(request: OperationRequest) -> void:
	_cleanup_request(request.source_player_id, RequestState.CANCELLED)

func _on_request_completed(request: OperationRequest) -> void:
	_cleanup_request(request.source_player_id, RequestState.COMPLETED)

func _cleanup_request(player_id: int, status: RequestState) -> void:
	if !_pending_requests.has(player_id):
		return
	var request = _pending_requests[player_id]
	if request == _null_request:
		_pending_requests[player_id] = _null_request
		return
	_disconnect_request_signals(request)
	_pending_requests[player_id] = _null_request
	print("请求处理完成，玩家ID：%d，状态：%s" % [player_id, status])

func _disconnect_request_signals(request: OperationRequest) -> void:
	if request.cancelled.is_connected(_on_request_cancelled):
		request.cancelled.disconnect(_on_request_cancelled)
	if request.completed.is_connected(_on_request_completed):
		request.completed.disconnect(_on_request_completed)

## 设置玩家响应状态
func set_player_responsive(player_id: int, can_respond: bool) -> void:
	if can_respond:
		_enable_player_response(player_id)
	else:
		_disable_player_response(player_id)
	permissions_updated.emit()

func _enable_player_response(player_id: int) -> void:
	if !_pending_requests.has(player_id):
		_pending_requests[player_id] = _null_request
		return
	var current_request = _pending_requests[player_id]
	if current_request != _null_request:
		_cleanup_request(player_id, RequestState.CANCELLED)
		_pending_requests[player_id] = _null_request

func _disable_player_response(player_id: int) -> void:
	if !_pending_requests.has(player_id):
		return
	var request = _pending_requests[player_id]
	if request != _null_request:
		_cleanup_request(player_id, RequestState.CANCELLED)
	_pending_requests.erase(player_id)
## 检查玩家是否有待处理请求
func has_pending_request(player_id: int) -> bool:
	return _pending_requests.get(player_id, _null_request) != _null_request
## 检查玩家是否可响应
func is_player_responsive(player_id: int) -> bool:
	return _pending_requests.get(player_id, null) == _null_request
## 获取玩家的当前请求（如果是占位符则返回 null）
func get_player_request(player_id: int) -> OperationRequest:
	var request = _pending_requests.get(player_id, null)
	if request == _null_request:
		return null
	return request
