extends TransPack

class_name RenderRequest
var target_area: StringName

func send_to_player(peer_id: int) -> void:
	if peer_id != -1:
		GlobalTransport.send_render_request(peer_id, self)

# 统一的Item添加请求（替代原来的CardAdd和PlayerAdd）
class ItemAdd extends RenderRequest:
	var items: Array  # 可以包含CardPack或PlayerPack
	func _init(area: StringName, data: Array):
		target_area = area
		items = data
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		SerializationUtil.write(buffer, target_area)
		ItemSerializer.serialize_array(items, buffer)
	static func deserialize_from_buffer(buffer: StreamPeerBuffer,pack:TransPack = NULL_PACK) -> RenderRequest:
		var area: StringName = SerializationUtil.read(buffer, TYPE_STRING_NAME)
		var items: Array[TransPack] = ItemSerializer.deserialize_array(buffer)
		return ItemAdd.new(area, items)
static func get_class_name_static() -> StringName:
	return &"ItemAdd"

# 统一的Item移除请求（替代原来的CardRemove）
class ItemRemove extends RenderRequest:
	var uids: PackedInt32Array  # 可以是卡牌UID或玩家UID
	func _init(area: StringName, data: PackedInt32Array):
		target_area = area
		uids = data
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		SerializationUtil.write(buffer, target_area)
		SerializationUtil.write(buffer, uids)
	static func deserialize_from_buffer(buffer: StreamPeerBuffer,pack:TransPack = NULL_PACK) -> RenderRequest:
		var area: StringName = SerializationUtil.read(buffer, TYPE_STRING_NAME)
		var uids: PackedInt32Array = SerializationUtil.read(buffer, TYPE_PACKED_INT32_ARRAY)
		return ItemRemove.new(area, uids)
	static func get_class_name_static() -> StringName:
		return &"ItemRemove"
# 统一的Item更新请求（替代原来的PlayerUpdate）
class ItemUpdate extends RenderRequest:
	var item: TransPack  # 可以是CardPack或PlayerPack
	func _init(area: StringName, data: TransPack):
		target_area = area
		item = data
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		SerializationUtil.write(buffer, target_area)
		ItemSerializer.serialize(item, buffer)
	static func deserialize_from_buffer(buffer: StreamPeerBuffer,pack:TransPack = NULL_PACK) -> RenderRequest:
		var area: StringName = SerializationUtil.read(buffer, TYPE_STRING_NAME)
		var item: TransPack = ItemSerializer.deserialize(buffer)
		return ItemUpdate.new(area, item)
	static func get_class_name_static() -> StringName:
		return &"ItemUpdate"
