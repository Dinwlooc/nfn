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
## 请求被取消
## @emitter
signal cancelled()
## 请求已完成
## @emitter
signal completed()
## 包类名的静态标识
## @override
static func get_class_name_static() -> StringName:
	return &"base_request"
## 标记为 NPC 发起（对等体 id 置 -1）
## @side_effect
func use_npc_peer_id() -> OperationRequest:
	source_peer_id = -1
	return self
## 取消请求并广播
## @side_effect @emitter
func cancel() -> void:
	state = State.CANCELLED
	cancelled.emit()
## 完成请求并广播
## @side_effect @emitter
func complete() -> void:
	state = State.COMPLETED
	completed.emit()
## 序列化：只写来源玩家 id
## @override @side_effect
func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	TransPackSerializer.write(buffer, source_player_id)
## 反序列化：读出来源玩家 id
## @override
static func deserialize_from_buffer(buffer: StreamPeerBuffer,pack:TransPack = OperationRequest.new()) -> OperationRequest:
	pack.source_player_id = TransPackSerializer.read(buffer, TYPE_INT)
	return pack

## 出牌请求：卡牌 id + 目标 id
class PlayCard extends OperationRequest:
	## 要打出的卡牌 id
	var _card_id: int
	## 目标玩家 id
	var _target_id: int
	## 构造：绑定来源玩家、卡牌与目标
	func _init(player_id:int = 0,card_id:int = -1,target_id:int = 0) -> void:
		source_player_id = player_id
		_card_id = card_id
		_target_id = target_id
	## 包类名标识
	## @override
	static func get_class_name_static() -> StringName:
		return &"play_card"
	## 序列化：先写基类字段，再写卡牌与目标 id
	## @override @side_effect
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		super.serialize_to_buffer(buffer)
		TransPackSerializer.write(buffer, _card_id)
		TransPackSerializer.write(buffer, _target_id)
	## 反序列化：先读基类字段，再读卡牌与目标 id
	## @override
	static func deserialize_from_buffer(buffer: StreamPeerBuffer,pack:TransPack = PlayCard.new()) -> OperationRequest:
		super.deserialize_from_buffer(buffer,pack)
		pack ._card_id = TransPackSerializer.read(buffer, TYPE_INT)
		pack ._target_id = TransPackSerializer.read(buffer, TYPE_INT)
		return pack
## 放弃响应操作请求，通常产生与响应超时相同的效果。
class AbandonResponse extends OperationRequest:
	## 包类名标识
	## @override
	static func get_class_name_static() -> StringName:
		return &"abandon_response"
	## 构造：绑定来源玩家
	func _init(player_id:int = 0) -> void:
		source_player_id = player_id
	## 反序列化：只有基类字段
	## @override
	static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = AbandonResponse.new()) -> OperationRequest:
		super.deserialize_from_buffer(buffer,pack)
		return pack

## 弃牌请求：待弃置的卡牌 id 列表
class DiscardCards extends OperationRequest:
	## 要弃置的卡牌 id 列表
	var _card_ids: PackedInt32Array

	## 构造：绑定来源玩家与卡牌列表
	func _init(player_id: int = 0, card_ids: PackedInt32Array = PackedInt32Array()) -> void:
		source_player_id = player_id
		_card_ids = card_ids

	## 包类名标识
	## @override
	static func get_class_name_static() -> StringName:
		return &"discard_cards"

	## 序列化：先写基类字段，再写张数与每个 id
	## @override @side_effect
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		super.serialize_to_buffer(buffer)
		TransPackSerializer.write(buffer, _card_ids.size())
		for id in _card_ids:
			TransPackSerializer.write(buffer, id)

	## 反序列化：先读基类字段，再按张数读回每个 id
	## @override
	static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = DiscardCards.new()) -> OperationRequest:
		super.deserialize_from_buffer(buffer, pack)
		var size: int = TransPackSerializer.read(buffer, TYPE_INT)
		var ids: PackedInt32Array = []
		for i in size:
			ids.append(TransPackSerializer.read(buffer, TYPE_INT))
		pack._card_ids = ids
		return pack
