extends RefCounted
class_name RenderRequest

# 移除类型枚举和属性
var target_area: StringName  # 公共区域字段
# 基础序列化接口
func serialize() -> PackedByteArray:
	return RenderRequestSerializer.serialize(self)
# 静态反序列化方法
static func deserialize(serialized_data: PackedByteArray):
	return RenderRequestSerializer.deserialize(serialized_data)
# 发送给玩家
func send_to_player(player_id: int) -> void:
	GlobalTransport.send_render_request(player_id, self)
# 序列化虚拟方法（子类实现）
func serialize_to_buffer(_buffer: StreamPeerBuffer) -> void:
	pass
class CardAdd extends RenderRequest:
	var card_data: Array[CardPack] 
	func _init(area: StringName, data: Array[CardPack]):
		target_area = area
		card_data = data
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		SerializationUtil.write(buffer, target_area)
		var serialized_cards:PackedByteArray = CardSerializer.serialize_array(card_data)
		SerializationUtil.write(buffer, serialized_cards)
	static func deserialize_from_buffer(buffer: StreamPeerBuffer) -> RenderRequest:
		var area:StringName = SerializationUtil.read(buffer, TYPE_STRING_NAME)
		var card_bytes:PackedByteArray = SerializationUtil.read(buffer, TYPE_PACKED_BYTE_ARRAY)
		var cards:Array[CardPack] = CardSerializer.deserialize_array(card_bytes) as Array[CardPack]
		return CardAdd.new(area, cards)

# 移除卡牌请求
class CardRemove extends RenderRequest:
	var uids_data: PackedInt32Array
	func _init(area: StringName, data: PackedInt32Array):
		target_area = area
		uids_data = data
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		SerializationUtil.write(buffer, target_area)
		SerializationUtil.write(buffer, uids_data)
	static func deserialize_from_buffer(buffer: StreamPeerBuffer) -> RenderRequest:
		var area = SerializationUtil.read(buffer, TYPE_STRING_NAME) as StringName
		var uids = SerializationUtil.read(buffer, TYPE_PACKED_INT32_ARRAY)
		return CardRemove.new(area, uids)
