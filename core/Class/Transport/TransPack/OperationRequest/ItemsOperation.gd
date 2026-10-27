## 物品操作请求：官方操作以枚举区分，自定义操作以枚举 0 + 自定义名扩展。
## 参数面统一为「源区域 + ids + 目标区域 + 目标 ids」，字段在构造时按操作类型的标准态物化，读取不再做隐式补全。
## 区域名为区域类型名（GlobalConstants.DefaultArea），不含归属玩家：私有区域归属请求者，
## 公共区域（center/discard/drawing）由公共玩家 id 承载，玩家区（players）在系统层由玩家管理器承载、不是 Area。
extends OperationRequest
class_name ItemsOperation

#== 类型 ==
## 操作类型；0 为自定义模式，其余为官方操作
enum Type {
	CUSTOM,
	PLAY_CARD,
	DISCARD_CARDS,
	RESPOND_CARD,
}

#== Properties ==
## 操作类型，决定标准态与分派键
var operation_type: Type = Type.CUSTOM
## 自定义操作名，仅在 operation_type 为 CUSTOM 时序列化与分派
var custom_name: StringName = &""
## 源区域名；标准态按操作类型给定
var source_area: StringName = &""
## 源侧物品 id 列表
var ids: PackedInt32Array = PackedInt32Array()
## 目标区域名；标准态按操作类型给定
var target_area: StringName = &""
## 目标侧 id 列表（目标为玩家时即玩家 id）
var target_ids: PackedInt32Array = PackedInt32Array()

#== Constructor ==
## 构造：绑定来源玩家与操作类型，并把区域物化为该类型的标准态
func _init(p_player_id: int = 0, p_operation_type: Type = Type.CUSTOM, p_custom_name: StringName = &"") -> void:
	source_player_id = p_player_id
	operation_type = p_operation_type
	custom_name = p_custom_name
	reset_to_standard()

#== 分派 ==
## 包类名标识，同时是序列化注册表的键
## @override
static func get_class_name_static() -> StringName:
	return &"items_operation"
## 取操作分派键：官方类型返回固定名，自定义类型返回自定义名
## @override
func get_operation_name() -> StringName:
	match operation_type:
		Type.PLAY_CARD:
			return &"play_card"
		Type.DISCARD_CARDS:
			return &"discard_cards"
		Type.RESPOND_CARD:
			return &"respond_card"
		_:
			return custom_name

#== Accessors ==
## 取源侧首个物品 id，列表为空时返回 0
func get_primary_id() -> int:
	return ids[0] if not ids.is_empty() else 0
## 取目标侧首个 id（目标为玩家时为玩家 id），无目标时返回 0
func get_primary_target_id() -> int:
	return target_ids[0] if not target_ids.is_empty() else 0

#== Factories ==
## 出牌请求：标准态源区域为请求者手牌区、目标区域为玩家区；目标缺省 0 表示无目标
## @factory
static func play_card(player_id: int, card_id: int, target_id: int = 0) -> ItemsOperation:
	var request: ItemsOperation = ItemsOperation.new(player_id, Type.PLAY_CARD)
	request.ids = PackedInt32Array([card_id])
	request.target_ids = PackedInt32Array([target_id])
	return request
## 弃牌请求：标准态源区域为请求者手牌区，无目标区域；弃置终点由弃牌命令决定
## @factory
static func discard_cards(player_id: int, card_ids: PackedInt32Array) -> ItemsOperation:
	var request: ItemsOperation = ItemsOperation.new(player_id, Type.DISCARD_CARDS)
	request.ids = card_ids
	return request
## 响应声明请求：标准态源区域为请求者手牌区，牌不离手，无目标
## @factory
static func respond_card(player_id: int, card_id: int) -> ItemsOperation:
	var request: ItemsOperation = ItemsOperation.new(player_id, Type.RESPOND_CARD)
	request.ids = PackedInt32Array([card_id])
	return request
## 自定义操作请求：最广参数面，四类参数均可显式指定
## @factory
static func custom(
	player_id: int,
	name: StringName,
	source_area_val: StringName = &"",
	ids_val: PackedInt32Array = PackedInt32Array(),
	target_area_val: StringName = &"",
	target_ids_val: PackedInt32Array = PackedInt32Array()
) -> ItemsOperation:
	var request: ItemsOperation = ItemsOperation.new(player_id, Type.CUSTOM, name)
	request.source_area = source_area_val
	request.ids = ids_val
	request.target_area = target_area_val
	request.target_ids = target_ids_val
	return request

#== 标准态 ==
## 把区域物化为当前操作类型的标准值，并清空两侧 id 列表
## @side_effect
func reset_to_standard() -> void:
	ids = PackedInt32Array()
	target_ids = PackedInt32Array()
	match operation_type:
		Type.PLAY_CARD:
			source_area = GlobalConstants.DefaultArea.HAND
			target_area = GlobalConstants.DefaultArea.PLAYERS
		Type.DISCARD_CARDS, Type.RESPOND_CARD:
			source_area = GlobalConstants.DefaultArea.HAND
			target_area = &""
		_:
			source_area = &""
			target_area = &""

#== Serialization ==
## 序列化：来源玩家、类型（自定义时附名）、源区域、ids、目标区域、目标 ids
## @override @side_effect
func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	super.serialize_to_buffer(buffer)
	TransPackSerializer.write(buffer, operation_type)
	if operation_type == Type.CUSTOM:
		TransPackSerializer.write(buffer, custom_name)
	TransPackSerializer.write(buffer, source_area)
	TransPackSerializer.write(buffer, ids)
	TransPackSerializer.write(buffer, target_area)
	TransPackSerializer.write(buffer, target_ids)
## 反序列化：与序列化同序
## @override
static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = ItemsOperation.new()) -> OperationRequest:
	super.deserialize_from_buffer(buffer, pack)
	var operation: ItemsOperation = pack as ItemsOperation
	operation.operation_type = TransPackSerializer.read(buffer, TYPE_INT)
	if operation.operation_type == Type.CUSTOM:
		operation.custom_name = TransPackSerializer.read(buffer, TYPE_STRING_NAME)
	operation.source_area = TransPackSerializer.read(buffer, TYPE_STRING_NAME)
	operation.ids = TransPackSerializer.read(buffer, TYPE_PACKED_INT32_ARRAY)
	operation.target_area = TransPackSerializer.read(buffer, TYPE_STRING_NAME)
	operation.target_ids = TransPackSerializer.read(buffer, TYPE_PACKED_INT32_ARRAY)
	return operation
