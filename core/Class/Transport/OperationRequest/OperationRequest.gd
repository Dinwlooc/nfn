extends RefCounted
class_name OperationRequest
#操作事件，客户端渲染层向服务器端逻辑层单向通信的媒介。
#需要重建对象。
var type: int

func serialize() -> PackedByteArray:
	return OperationRequestSerializer.serialize(self)

static func deserialize(serialized_data: PackedByteArray) -> OperationRequest:
	return OperationRequestSerializer.deserialize(serialized_data)

class PlayCard extends OperationRequest:
	var card_id:int
	var target_ids:int
