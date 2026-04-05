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
		CUSTOM, DRAW, ACQUIRE, GENERATE, DISCARD, DEATH, HIDE, UPDATE, STRIKE, ATTACK,
	}
	var event_type: EventType
	var event_source_player_id: int = PUBLIC_AREA_PLAYER_ID
	var custom_event_name: StringName
	var items: Array[ItemPack] = []

	# 新增：原区域信息（用于渲染层自动识别）
	var source_area_name: StringName = &""
	var source_area_player_id: int = PUBLIC_AREA_PLAYER_ID
	# 内部掩码
	var _mask: int = 0
	enum SourceMask {
		NONE = 0,
		AREA_NAME = 1 << 0,
		PLAYER_ID = 1 << 1,
	}

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
		# 初始化原区域字段默认为目标区域相同（避免额外传输）
		source_area_name = target_area_name
		source_area_player_id = area_player_id

	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		super.serialize_to_buffer(buffer)
		SerializationUtil.write(buffer, event_type)
		SerializationUtil.write(buffer, event_source_player_id)
		if event_type == EventType.CUSTOM:
			SerializationUtil.write(buffer, custom_event_name)
		ItemSerializer.serialize_array(items, buffer)

		# 计算掩码：仅当与原区域与目标区域不同时才传输
		_mask = SourceMask.NONE
		if source_area_name != target_area:
			_mask |= SourceMask.AREA_NAME
		if source_area_player_id != target_area_player_id:
			_mask |= SourceMask.PLAYER_ID
		SerializationUtil.write(buffer, _mask)
		if _mask & SourceMask.AREA_NAME:
			SerializationUtil.write(buffer, source_area_name)
		if _mask & SourceMask.PLAYER_ID:
			SerializationUtil.write(buffer, source_area_player_id)

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

			# 读取掩码并恢复原区域字段
			var mask: int = SerializationUtil.read(buffer, TYPE_INT)
			if mask & SourceMask.AREA_NAME:
				item_set.source_area_name = SerializationUtil.read(buffer, TYPE_STRING_NAME)
			else:
				item_set.source_area_name = item_set.target_area
			if mask & SourceMask.PLAYER_ID:
				item_set.source_area_player_id = SerializationUtil.read(buffer, TYPE_INT)
			else:
				item_set.source_area_player_id = item_set.target_area_player_id
		return pack

	static func get_class_name_static() -> StringName:
		return &"ItemSet"
# 卡牌数量变化渲染请求，携带变化后的总数量及事件信息
class ItemCountSet extends RenderRequest:
	var total_count: int = 0
	var event_type: ItemSet.EventType = ItemSet.EventType.CUSTOM
	var event_source_player_id: int = PUBLIC_AREA_PLAYER_ID
	var custom_event_name: StringName = &""

	# 新增：原区域信息
	var source_area_name: StringName = &""
	var source_area_player_id: int = PUBLIC_AREA_PLAYER_ID
	var _mask: int = 0
	enum SourceMask {
		NONE = 0,
		AREA_NAME = 1 << 0,
		PLAYER_ID = 1 << 1,
	}

	func _init(
		target_area_name: StringName = &"",
		count: int = 0,
		event_type_val: ItemSet.EventType = ItemSet.EventType.CUSTOM,
		area_player_id: int = PUBLIC_AREA_PLAYER_ID,
		source_player_id: int = area_player_id,
		custom_name: StringName = &"",
	) -> void:
		target_area = target_area_name
		total_count = count
		event_type = event_type_val
		event_source_player_id = source_player_id
		custom_event_name = custom_name
		target_area_player_id = area_player_id
		source_area_name = target_area_name
		source_area_player_id = area_player_id

	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		super.serialize_to_buffer(buffer)
		SerializationUtil.write(buffer, total_count)
		SerializationUtil.write(buffer, event_type)
		SerializationUtil.write(buffer, event_source_player_id)
		if event_type == ItemSet.EventType.CUSTOM:
			SerializationUtil.write(buffer, custom_event_name)

		_mask = SourceMask.NONE
		if source_area_name != target_area:
			_mask |= SourceMask.AREA_NAME
		if source_area_player_id != target_area_player_id:
			_mask |= SourceMask.PLAYER_ID
		SerializationUtil.write(buffer, _mask)
		if _mask & SourceMask.AREA_NAME:
			SerializationUtil.write(buffer, source_area_name)
		if _mask & SourceMask.PLAYER_ID:
			SerializationUtil.write(buffer, source_area_player_id)

	static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = NULL_PACK) -> RenderRequest:
		if pack == NULL_PACK:
			pack = ItemCountSet.new()
		super.deserialize_from_buffer(buffer, pack)
		var count_set = pack as ItemCountSet
		if count_set:
			count_set.total_count = SerializationUtil.read(buffer, TYPE_INT)
			count_set.event_type = SerializationUtil.read(buffer, TYPE_INT)
			count_set.event_source_player_id = SerializationUtil.read(buffer, TYPE_INT)
			if count_set.event_type == ItemSet.EventType.CUSTOM:
				count_set.custom_event_name = SerializationUtil.read(buffer, TYPE_STRING_NAME)

			var mask: int = SerializationUtil.read(buffer, TYPE_INT)
			if mask & SourceMask.AREA_NAME:
				count_set.source_area_name = SerializationUtil.read(buffer, TYPE_STRING_NAME)
			else:
				count_set.source_area_name = count_set.target_area
			if mask & SourceMask.PLAYER_ID:
				count_set.source_area_player_id = SerializationUtil.read(buffer, TYPE_INT)
			else:
				count_set.source_area_player_id = count_set.target_area_player_id
		return pack

	static func get_class_name_static() -> StringName:
		return &"ItemCountSet"
