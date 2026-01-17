extends TransPack

class_name RenderRequest
var target_area: StringName

func send_to_player(peer_id: int) -> void:
	if peer_id != -1:
		GlobalTransport.send_render_request(peer_id, self)

class ItemSet extends RenderRequest:
	var item_type: StringName
	var items: Array[ItemPack] = []

	func _init(target: StringName, item_type: StringName, items_array: Array[ItemPack]) -> void:
		target_area = target
		self.item_type = item_type
		self.items = items_array

	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		SerializationUtil.write(buffer, target_area)
		SerializationUtil.write(buffer, item_type)
		ItemSerializer.serialize_array(items, buffer)

	static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = NULL_PACK) -> RenderRequest:
		var area: StringName = SerializationUtil.read(buffer, TYPE_STRING_NAME)
		var item_type: StringName = SerializationUtil.read(buffer, TYPE_STRING_NAME)
		var items: Array[ItemPack] = ItemSerializer.deserialize_array(buffer)
		return ItemSet.new(area, item_type, items)

	static func get_class_name_static() -> StringName:
		return &"ItemSet"
