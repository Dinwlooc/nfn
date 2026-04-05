extends RefCounted
class_name OperationHandler

var _peer_player_map: Dictionary[int, int] = {}
var _pending_requests: Dictionary[int, OperationRequest] = {}
var _null_request: OperationRequest = OperationRequest.new()
signal operation_validated(request: OperationRequest)
## 信号参数为当前可响应的玩家 ID 列表
signal permissions_updated(responsive_player_ids: PackedInt32Array)

enum RequestState { CANCELLED, COMPLETED }

func update_verification_mapping(peer_id: int, player_id: int) -> void:
	_peer_player_map[peer_id] = player_id

func verify_operation(request: OperationRequest) -> bool:
	if request == _null_request:
		return false
	if request.source_peer_id == -1:
		return true
	var source_player_id = _peer_player_map.get(request.source_peer_id, -1)
	return source_player_id == request.source_player_id

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

## 检查玩家是否可以接受新请求：
## - 如果玩家在 _pending_requests 中不存在，视为不可响应（需要先启用）
## - 如果存在且值为 _null_request，则可以接受
func _can_accept_new_request(player_id: int) -> bool:
	return _pending_requests.get(player_id) == _null_request

func _setup_request_tracking(player_id: int, request: OperationRequest) -> void:
	_pending_requests[player_id] = request
	request.cancelled.connect(_on_request_cancelled.bind(request))
	request.completed.connect(_on_request_completed.bind(request))

func _on_request_cancelled(request: OperationRequest) -> void:
	# 请求被取消时，清理槽位（因为未生效）
	_cleanup_request(request.source_player_id)
	GlobalConsole._print(["请求取消，玩家ID：%d" % request.source_player_id])

func _on_request_completed(request: OperationRequest) -> void:
	# 请求完成后，不清空槽位，保持阻塞状态，等待下次启用
	# 注意：此时 _pending_requests[player_id] 仍指向该 request 对象
	GlobalConsole._print(["请求处理完成，玩家ID：%d，等待响应权重新授予" % request.source_player_id])

## 清理请求槽位（将槽位重置为 _null_request，表示可接受新请求）
func _cleanup_request(player_id: int) -> void:
	if not _pending_requests.has(player_id):
		return
	var request:OperationRequest = _pending_requests[player_id]
	if request == _null_request:
		return
	# 如果请求尚未完成/取消，主动取消它
	if request.state == OperationRequest.State.PROCESS:
		request.cancel()
	_disconnect_request_signals(request)
	_pending_requests[player_id] = _null_request

func _disconnect_request_signals(request: OperationRequest) -> void:
	if request.cancelled.is_connected(_on_request_cancelled):
		request.cancelled.disconnect(_on_request_cancelled)
	if request.completed.is_connected(_on_request_completed):
		request.completed.disconnect(_on_request_completed)

## 设置玩家响应状态（启用/禁用）
func set_player_responsive(player_id: int, can_respond: bool) -> void:
	if can_respond:
		_enable_player_response(player_id)
	else:
		_disable_player_response(player_id)
	permissions_updated.emit(_get_responsive_player_ids())

## 启用玩家响应权：
## - 如果玩家没有槽位，则创建 _null_request 槽位
## - 如果玩家有槽位（无论是 _null_request 还是已完成请求的占位），都重置为 _null_request
func _enable_player_response(player_id: int) -> void:
	if not _pending_requests.has(player_id):
		_pending_requests[player_id] = _null_request
		return
	var current = _pending_requests[player_id]
	if current != _null_request:
		# 存在未完成或已完成的请求，主动清理（取消请求，重置槽位）
		_cleanup_request(player_id)
	# 如果已经是 _null_request，无需操作

## 禁用玩家响应权：
## - 如果玩家存在槽位且不是 _null_request（有未完成请求），则取消请求并清理槽位
## - 最后删除槽位（使玩家完全不可响应）
func _disable_player_response(player_id: int) -> void:
	if not _pending_requests.has(player_id):
		return
	var request = _pending_requests[player_id]
	if request != _null_request:
		_cleanup_request(player_id)  # 取消请求，重置为 _null_request
	# 删除槽位（表示该玩家不在响应权名单中）
	_pending_requests.erase(player_id)

## 检查玩家是否有待处理请求（包括未完成和已完成的）
func has_pending_request(player_id: int) -> bool:
	var req = _pending_requests.get(player_id, _null_request)
	return req != _null_request

## 检查玩家是否当前可以响应（即槽位为 _null_request）
func is_player_responsive(player_id: int) -> bool:
	return _pending_requests.get(player_id, null) == _null_request

## 获取玩家的当前请求（如果槽位是 _null_request 则返回 null）
func get_player_request(player_id: int) -> OperationRequest:
	var request = _pending_requests.get(player_id, null)
	if request == _null_request:
		return null
	return request

## 批量设置响应玩家
func set_responsive_players(player_ids: PackedInt32Array) -> void:
	# 先禁用所有当前有记录的玩家（注意：只对存在的键操作）
	var current_players = _pending_requests.keys().duplicate()
	for pid in current_players:
		_disable_player_response(pid)
	# 再启用新列表中的玩家
	for pid in player_ids:
		_enable_player_response(pid)
	permissions_updated.emit(_get_responsive_player_ids())

## 辅助函数：获取当前可响应的玩家 ID 列表（槽位为 _null_request）
func _get_responsive_player_ids() -> PackedInt32Array:
	var ids: PackedInt32Array = []
	for player_id in _pending_requests:
		if _pending_requests[player_id] == _null_request:
			ids.append(player_id)
	return ids
