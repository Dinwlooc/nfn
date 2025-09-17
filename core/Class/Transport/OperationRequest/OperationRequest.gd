extends TransPack
class_name OperationRequest

func send()->void:
	GlobalTransport.upload_operation_request(self)
	pass
# 实现类：打牌操作
class PlayCard extends OperationRequest:
	var card_id: int
	var target_id: int  # 修复变量名拼写错误
	# 实例序列化方法
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		TransPackSerializer.write(buffer, card_id)
		TransPackSerializer.write(buffer, target_id)
	# 静态反序列化方法
	static func deserialize_from_buffer(buffer: StreamPeerBuffer) -> OperationRequest:
		var instance = PlayCard.new()
		instance.card_id = TransPackSerializer.read(buffer, TYPE_INT)
		instance.target_id = TransPackSerializer.read(buffer, TYPE_INT)
		return instance
