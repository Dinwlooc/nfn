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
	enum EventType {
		CUSTOM,    # 自定义
		DRAW,      # 抽取
		ACQUIRE,   # 获取
		GENERATE,  # 生成
		DISCARD,   # 弃置
		DEATH,     # 死亡
		HIDE,      # 隐藏
		UPDATE,
		STRIKE,    # 打入
		ATTACK,    # 攻击
	}
	var event_type: EventType
	var event_source_player_id: int = PUBLIC_AREA_PLAYER_ID
	var custom_event_name: StringName
	var items: Array[ItemPack] = []

	func _init(
		target_area_name: StringName = &"",
		event_type_val: EventType = EventType.CUSTOM,
		items_array: Array[ItemPack] = [],
		area_player_id: int = PUBLIC_AREA_PLAYER_ID,
		source_player_id: int = area_player_id,
		custom_name: StringName = &"",
	) -> void:
		target_area = target_area_name
		event_type = event_type_val
		event_source_player_id = source_player_id
		custom_event_name = custom_name
		items = items_array
		target_area_player_id = area_player_id

	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		super.serialize_to_buffer(buffer)
		SerializationUtil.write(buffer, event_type)  # 枚举作为整数写入
		SerializationUtil.write(buffer, event_source_player_id)
		if event_type == EventType.CUSTOM:
			SerializationUtil.write(buffer, custom_event_name)
		ItemSerializer.serialize_array(items, buffer)

	static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = NULL_PACK) -> RenderRequest:
		if pack == NULL_PACK:
			pack = ItemSet.new()
		super.deserialize_from_buffer(buffer, pack)
		var item_set = pack as ItemSet
		if item_set:
			item_set.event_type = SerializationUtil.read(buffer, TYPE_INT)
			item_set.event_source_player_id = SerializationUtil.read(buffer, TYPE_INT)
			if item_set.event_type == EventType.CUSTOM:
				item_set.custom_event_name = SerializationUtil.read(buffer, TYPE_STRING_NAME)
			item_set.items = ItemSerializer.deserialize_array(buffer)
		return pack

	static func get_class_name_static() -> StringName:
		return &"ItemSet"
