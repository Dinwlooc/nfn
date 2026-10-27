extends TransPack
class_name OperationRequest

## 操作请求的生命周期状态
enum State{ PROCESS,CANCELLED,COMPLETED }

## 来源对等体 id（-1 表示由 NPC 发起）
var source_peer_id:int
## 来源玩家 id
var source_player_id:int
## 当前状态
var state:State = State.PROCESS
## 请求被取消，携带请求自身
## @emitter
signal cancelled(request: OperationRequest)
## 请求已完成，携带请求自身
## @emitter
signal completed(request: OperationRequest)
## 包类名的静态标识
## @override
static func get_class_name_static() -> StringName:
	return &"base_request"
## 取操作分派键，供阶段按操作类型分发；基类无操作类型
## @hook
func get_operation_name() -> StringName:
	return &""
## 标记为 NPC 发起（对等体 id 置 -1）
## @side_effect
func use_npc_peer_id() -> OperationRequest:
	source_peer_id = -1
	return self
## 取消请求并广播
## @side_effect @emitter
func cancel() -> void:
	state = State.CANCELLED
	cancelled.emit(self)
## 完成请求并广播
## @side_effect @emitter
func complete() -> void:
	state = State.COMPLETED
	completed.emit(self)
## 序列化：只写来源玩家 id
## @override @side_effect
func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	TransPackSerializer.write(buffer, source_player_id)
## 反序列化：读出来源玩家 id
## @override
static func deserialize_from_buffer(buffer: StreamPeerBuffer,pack:TransPack = OperationRequest.new()) -> OperationRequest:
	pack.source_player_id = TransPackSerializer.read(buffer, TYPE_INT)
	return pack

## 通用放弃请求：不带参数，表示来源方放弃当前响应或操作；不属于物品操作族。
class AbandonResponse extends OperationRequest:
	## 构造：绑定来源玩家
	func _init(player_id: int = 0) -> void:
		source_player_id = player_id
	## 包类名标识
	## @override
	static func get_class_name_static() -> StringName:
		return &"abandon_response"
	## 取操作分派键
	## @override
	func get_operation_name() -> StringName:
		return &"abandon_response"
	## 反序列化：只有基类字段
	## @override
	static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = AbandonResponse.new()) -> OperationRequest:
		super.deserialize_from_buffer(buffer, pack)
		return pack
