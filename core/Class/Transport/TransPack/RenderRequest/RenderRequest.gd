extends TransPack
class_name RenderRequest

const PUBLIC_AREA_PLAYER_ID: int = 1
var target_area: StringName
var target_area_player_id: int = PUBLIC_AREA_PLAYER_ID
## 自定义参数字典（所有子类通用）
var custom_params: Dictionary[StringName,Variant]= {}

func send_to_player(peer_id: int) -> void:
	GlobalTransport.send_render_request(peer_id, self)

## 设置自定义参数字典（基类默认实现，不限制事件类型）
func set_custom_params(params: Dictionary[StringName,Variant]) -> void:
	custom_params = params

func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	SerializationUtil.write(buffer, target_area)
	var mask: int = 0
	if target_area_player_id != PUBLIC_AREA_PLAYER_ID:
		mask |= 1
	SerializationUtil.write(buffer, mask)
	if mask & 1:
		SerializationUtil.write(buffer, target_area_player_id)

static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = NULL_PACK) -> RenderRequest:
	if pack == NULL_PACK:
		pack = RenderRequest.new()
	pack.target_area = SerializationUtil.read(buffer, TYPE_STRING_NAME)
	var mask: int = SerializationUtil.read(buffer, TYPE_INT)
	if mask & 1:
		pack.target_area_player_id = SerializationUtil.read(buffer, TYPE_INT)
	else:
		pack.target_area_player_id = PUBLIC_AREA_PLAYER_ID
	return pack

# ========== ItemSet ==========
class ItemSet extends RenderRequest:
	enum EventType {
		CUSTOM, DRAW, ACQUIRE, GENERATE, DISCARD, DEATH, HIDE, UPDATE, STRIKE, ATTACK, TRANSFER
	}
	var event_type: EventType
	var event_source_player_id: int = PUBLIC_AREA_PLAYER_ID
	var items: Array[ItemPack] = []
	var source_area_name: StringName
	var source_area_player_id: int
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
		override_source_area_name: StringName = target_area_name,
		override_source_area_player_id: int = area_player_id,
	) -> void:
		target_area = target_area_name
		event_type = event_type_val
		event_source_player_id = source_area_player_id
		items = items_array
		target_area_player_id = area_player_id
		source_area_name = override_source_area_name
		source_area_player_id = override_source_area_player_id

	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		super.serialize_to_buffer(buffer)
		SerializationUtil.write(buffer, event_type)
		SerializationUtil.write(buffer, event_source_player_id)
		if event_type == EventType.CUSTOM:
			SerializationUtil.write(buffer, JSON.stringify(custom_params))
		ItemSerializer.serialize_array(items, buffer)
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
				var json_str: String = SerializationUtil.read(buffer, TYPE_STRING)
				if not json_str.is_empty():
					item_set.custom_params = JSON.parse_string(json_str)
			item_set.items = ItemSerializer.deserialize_array(buffer)
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


# ========== ItemCountSet ==========
class ItemCountSet extends RenderRequest:
	var total_count: int = 0
	var event_type: ItemSet.EventType = ItemSet.EventType.CUSTOM
	var event_source_player_id: int = PUBLIC_AREA_PLAYER_ID
	var source_area_name: StringName
	var source_area_player_id: int
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
		override_source_area_name: StringName = target_area_name,
		override_source_area_player_id: int = area_player_id,
	) -> void:
		target_area = target_area_name
		total_count = count
		event_type = event_type_val
		event_source_player_id = source_area_player_id
		target_area_player_id = area_player_id
		source_area_name = override_source_area_name
		source_area_player_id = override_source_area_player_id

	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		super.serialize_to_buffer(buffer)
		SerializationUtil.write(buffer, total_count)
		SerializationUtil.write(buffer, event_type)
		SerializationUtil.write(buffer, event_source_player_id)
		if event_type == ItemSet.EventType.CUSTOM:
			SerializationUtil.write(buffer, JSON.stringify(custom_params))
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
				var json_str: String = SerializationUtil.read(buffer, TYPE_STRING)
				if not json_str.is_empty():
					count_set.custom_params = JSON.parse_string(json_str)
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
# ========== StageNotifyRequest ==========
class StageNotifyRequest extends RenderRequest:
	var current_player_id: int
	var stage_name: StringName
	## 临时阶段归属玩家 ID（0 表示主阶段，非 0 表示临时阶段并属于该玩家）
	var temporary_stage_player_id: int

	func _init(player_id: int, stage: StringName, temp_owner_id: int = 0, params: Dictionary[StringName,Variant] = {}) -> void:
		target_area = GlobalConstants.DefaultArea.CENTER
		target_area_player_id = PUBLIC_AREA_PLAYER_ID
		current_player_id = player_id
		stage_name = stage
		temporary_stage_player_id = temp_owner_id
		custom_params = params

	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		super.serialize_to_buffer(buffer)
		SerializationUtil.write(buffer, current_player_id)
		SerializationUtil.write(buffer, stage_name)
		SerializationUtil.write(buffer, temporary_stage_player_id)
		SerializationUtil.write(buffer, custom_params)

	static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = NULL_PACK) -> RenderRequest:
		if pack == NULL_PACK:
			pack = StageNotifyRequest.new(0, &"")
		super.deserialize_from_buffer(buffer, pack)
		var req = pack as StageNotifyRequest
		if req:
			req.current_player_id = SerializationUtil.read(buffer, TYPE_INT)
			req.stage_name = SerializationUtil.read(buffer, TYPE_STRING_NAME)
			req.temporary_stage_player_id = SerializationUtil.read(buffer, TYPE_INT)
			req.custom_params = SerializationUtil.read(buffer, TYPE_DICTIONARY)
		return pack

	static func get_class_name_static() -> StringName:
		return &"StageNotifyRequest"
