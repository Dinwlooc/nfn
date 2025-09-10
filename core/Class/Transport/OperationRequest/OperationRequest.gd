extends TransPack
class_name OperationRequest

# 实现类：打牌操作
class PlayCard extends OperationRequest:
	var card_id: int
	var target_id: int  # 修复变量名拼写错误
	# 实例序列化方法
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		BaseSerializer.write(buffer, card_id)
		BaseSerializer.write(buffer, target_id)
	# 静态反序列化方法
	static func deserialize_from_buffer(buffer: StreamPeerBuffer) -> OperationRequest:
		var instance = PlayCard.new()
		instance.card_id = BaseSerializer.read(buffer, TYPE_INT)
		instance.target_id = BaseSerializer.read(buffer, TYPE_INT)
		return instance
