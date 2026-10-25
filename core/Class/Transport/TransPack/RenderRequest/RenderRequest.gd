extends TransPack
class_name RenderRequest

## 公共区域玩家 id（非专有归属）
const PUBLIC_AREA_PLAYER_ID: int = 1
## 目标区域名
var target_area: StringName
## 目标区域的所属玩家 id
var target_area_player_id: int = PUBLIC_AREA_PLAYER_ID
## 自定义参数字典（所有子类通用）
var custom_params: Dictionary[StringName,Variant]
@warning_ignore("assert_always_true")
## 把本请求发送给指定对等体
## @side_effect
func send_to_player(peer_id: int) -> void:
	GlobalTransport.send_render_request(peer_id, self)
## 设置自定义参数字典（基类默认实现，不限制事件类型）
func set_custom_params(params: Dictionary[StringName,Variant]) -> void:
	custom_params = params

## 序列化：区域名、掩码与自定义参数
## @override @side_effect
func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	SerializationUtil.write(buffer, target_area)
	var mask: int = 0
	if target_area_player_id != PUBLIC_AREA_PLAYER_ID:
		mask |= 1
	SerializationUtil.write(buffer, mask)
	if mask & 1:
		SerializationUtil.write(buffer, target_area_player_id)
	SerializationUtil.write(buffer, custom_params)

## 反序列化：区域名、掩码与自定义参数
## @override
static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = RenderRequest.new()) -> RenderRequest:
	pack.target_area = SerializationUtil.read(buffer, TYPE_STRING_NAME)
	var mask: int = SerializationUtil.read(buffer, TYPE_INT)
	if mask & 1:
		pack.target_area_player_id = SerializationUtil.read(buffer, TYPE_INT)
	else:
		pack.target_area_player_id = PUBLIC_AREA_PLAYER_ID
	var dict:Dictionary[StringName,Variant] = SerializationUtil.read(buffer,TYPE_DICTIONARY)
	pack.custom_params = dict
	return pack


# ========== ItemSet ==========
## 一组物品的整包更新请求
class ItemSet extends RenderRequest:
	## 物品事件类型
	enum EventType {
		CUSTOM, DRAW, ACQUIRE, GENERATE, DISCARD, DEATH, HIDE, UPDATE, STRIKE, ATTACK, TRANSFER
	}
	## 事件类型
	var event_type: EventType
	## 事件来源玩家 id
	var event_source_player_id: int = PUBLIC_AREA_PLAYER_ID
	## 随请求下发的物品数据包
	var items: Array[ItemPack] = []
	## 来源区域名
	var source_area_name: StringName
	## 来源区域的所属玩家 id
	var source_area_player_id: int
	## 本次序列化的来源字段掩码
	var _mask: int = 0
	## 来源字段掩码位
	enum SourceMask {
		NONE = 0,
		AREA_NAME = 1 << 0,
		PLAYER_ID = 1 << 1,
	}

	## 构造：绑定目标区域、事件与物品列表
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

	## 序列化：先写基类字段，再写事件、物品与来源掩码
	## @override @side_effect
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		super.serialize_to_buffer(buffer)
		SerializationUtil.write(buffer, event_type)
		SerializationUtil.write(buffer, event_source_player_id)
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

	## 反序列化：读回事件、物品与来源掩码
	## @override
	static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = ItemSet.new()) -> RenderRequest:
		super.deserialize_from_buffer(buffer, pack)
		var item_set = pack as ItemSet
		if item_set:
			item_set.event_type = SerializationUtil.read(buffer, TYPE_INT)
			item_set.event_source_player_id = SerializationUtil.read(buffer, TYPE_INT)
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

	## 包类名标识
	## @override
	static func get_class_name_static() -> StringName:
		return &"ItemSet"


# ========== ItemCountSet ==========
## 物品数量更新请求（不携带物品数据包）
class ItemCountSet extends RenderRequest:
	## 区域当前物品总数
	var total_count: int = 0
	## 物品事件类型
	var event_type: ItemSet.EventType = ItemSet.EventType.CUSTOM
	## 事件来源玩家 id
	var event_source_player_id: int = PUBLIC_AREA_PLAYER_ID
	## 来源区域名
	var source_area_name: StringName
	## 来源区域的所属玩家 id
	var source_area_player_id: int
	## 本次序列化的来源字段掩码
	var _mask: int = 0
	## 来源字段掩码位
	enum SourceMask {
		NONE = 0,
		AREA_NAME = 1 << 0,
		PLAYER_ID = 1 << 1,
	}

	## 构造：绑定目标区域、数量与事件
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

	## 序列化：先写基类字段，再写数量、事件与来源掩码
	## @override @side_effect
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		super.serialize_to_buffer(buffer)
		SerializationUtil.write(buffer, total_count)
		SerializationUtil.write(buffer, event_type)
		SerializationUtil.write(buffer, event_source_player_id)
		# 删除了原来的 JSON.stringify(custom_params)，基类已处理
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

	## 反序列化：读回数量、事件与来源掩码
	## @override
	static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = ItemCountSet.new()) -> RenderRequest:
		super.deserialize_from_buffer(buffer, pack)
		var count_set = pack as ItemCountSet
		if count_set:
			count_set.total_count = SerializationUtil.read(buffer, TYPE_INT)
			count_set.event_type = SerializationUtil.read(buffer, TYPE_INT)
			count_set.event_source_player_id = SerializationUtil.read(buffer, TYPE_INT)
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

	## 包类名标识
	## @override
	static func get_class_name_static() -> StringName:
		return &"ItemCountSet"
# ========== StageNotifyRequest ==========
## 阶段变更通知请求
class StageNotifyRequest extends RenderRequest:
	## 当前行动玩家 id
	var current_player_id: int
	## 阶段名
	var stage_name: StringName
	## 临时阶段归属玩家 ID（0 表示主阶段，非 0 表示临时阶段并属于该玩家）
	var temporary_stage_player_id: int

	## 构造：绑定玩家、阶段与临时归属
	func _init(player_id: int = 0, stage: StringName = &"", temp_owner_id: int = 0, params: Dictionary[StringName,Variant] = {}) -> void:
		target_area = GlobalConstants.DefaultArea.CENTER
		target_area_player_id = PUBLIC_AREA_PLAYER_ID
		current_player_id = player_id
		stage_name = stage
		temporary_stage_player_id = temp_owner_id
		custom_params = params

	## 序列化：先写基类字段，再写玩家、阶段与临时归属
	## @override @side_effect
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		super.serialize_to_buffer(buffer)   # 基类已写入 custom_params
		SerializationUtil.write(buffer, current_player_id)
		SerializationUtil.write(buffer, stage_name)
		SerializationUtil.write(buffer, temporary_stage_player_id)

	## 反序列化：读回玩家、阶段与临时归属
	## @override
	static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = StageNotifyRequest.new()) -> RenderRequest:
		super.deserialize_from_buffer(buffer, pack)   # 基类已读取 custom_params
		pack.current_player_id = SerializationUtil.read(buffer, TYPE_INT)
		pack.stage_name = SerializationUtil.read(buffer, TYPE_STRING_NAME)
		pack.temporary_stage_player_id = SerializationUtil.read(buffer, TYPE_INT)
		return pack

	## 包类名标识
	## @override
	static func get_class_name_static() -> StringName:
		return &"StageNotifyRequest"
# ========== SettleSet ==========
## 守区结算摘要请求：结算计数与本次结算牌 / 对抗牌 id（未来可能扩展）
class SettleSet extends RenderRequest:
	## 守区当前结算次数
	var settle_count: int = 0
	## 本次结算牌 id（无则 -1）
	var settle_card_id: int = -1
	## 本次对抗牌 id（无则 -1）
	var oppose_card_id: int = -1

	## 构造：绑定守区归属玩家与结算摘要
	func _init(
		count: int = 0,
		settle_id: int = -1,
		oppose_id: int = -1,
		area_player_id: int = PUBLIC_AREA_PLAYER_ID,
	) -> void:
		target_area = GlobalConstants.DefaultArea.DEFENCE
		target_area_player_id = area_player_id
		settle_count = count
		settle_card_id = settle_id
		oppose_card_id = oppose_id

	## 序列化：先写基类字段，再写结算摘要
	## @override @side_effect
	func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
		super.serialize_to_buffer(buffer)
		SerializationUtil.write(buffer, settle_count)
		SerializationUtil.write(buffer, settle_card_id)
		SerializationUtil.write(buffer, oppose_card_id)

	## 反序列化：读回结算摘要
	## @override
	static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = SettleSet.new()) -> RenderRequest:
		super.deserialize_from_buffer(buffer, pack)
		var settle_set = pack as SettleSet
		if settle_set:
			settle_set.settle_count = SerializationUtil.read(buffer, TYPE_INT)
			settle_set.settle_card_id = SerializationUtil.read(buffer, TYPE_INT)
			settle_set.oppose_card_id = SerializationUtil.read(buffer, TYPE_INT)
		return pack

	## 包类名标识
	## @override
	static func get_class_name_static() -> StringName:
		return &"SettleSet"
