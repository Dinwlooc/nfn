extends TransPack
class_name RenderRequest

const PUBLIC_AREA_PLAYER_ID: int = -1

var target_area: StringName
var target_area_player_id: int = PUBLIC_AREA_PLAYER_ID

func send_to_player(peer_id: int) -> void:
	GlobalTransport.send_render_request(peer_id, self)

# 序列化公共属性
func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	SerializationUtil.write(buffer, target_area)
	SerializationUtil.write(buffer, target_area_player_id)

# 反序列化公共属性
static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = NULL_PACK) -> RenderRequest:
	if pack == NULL_PACK:
		pack = RenderRequest.new()
	pack.target_area = SerializationUtil.read(buffer, TYPE_STRING_NAME)
	pack.target_area_player_id = SerializationUtil.read(buffer, TYPE_INT)
	return pack


class ItemSet extends RenderRequest:
	var item_type: StringName
	var items: Array[ItemPack] = []
	func _init(target_area_name: StringName = "", item_type_name: StringName = "" , items_array: Array[ItemPack]=[] , target_area_player_id_int = PUBLIC_AREA_PLAYER_ID) -> void:
		target_area = target_area_name
		item_type = item_type_name
		items = items_array
		target_area_player_id = target_area_player_id_int
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		super.serialize_to_buffer(buffer)
		SerializationUtil.write(buffer, item_type)
		ItemSerializer.serialize_array(items, buffer)

	static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = NULL_PACK) -> RenderRequest:
		if pack == NULL_PACK:
			pack = ItemSet.new()
		super.deserialize_from_buffer(buffer, pack)
		pack.item_type = SerializationUtil.read(buffer, TYPE_STRING_NAME)
		pack.items = ItemSerializer.deserialize_array(buffer)
		return pack

	static func get_class_name_static() -> StringName:
		return &"ItemSet"
