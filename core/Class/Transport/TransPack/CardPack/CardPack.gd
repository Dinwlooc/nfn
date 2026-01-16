extends TransPack
class_name CardPack

enum MainProperty {
	NAME,
	TYPE,
	END  # 子类枚举衔接点
}

# 卡牌基础属性
var id: int
var name: StringName
var type: int
var merge_mask: int = 0
const CardType = GlobalConstants.KEY_CARD_TYPE
const NULL = GlobalConstants.CARD_TYPES[GlobalConstants.CardType.NULL]
const VERSION_MAX: int = 65535

static func init_from_card(card: Card) -> CardPack:
	return CardPack.new(card.id, card.name, card.type)

func _init(init_id: int = 0, init_name: StringName = &"", init_type_name: StringName = NULL):
	id = init_id
	name = init_name
	type = GlobalRegistry.get_constant_index(CardType, init_type_name)

# 序列化实现（使用枚举位）
func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	SerializationUtil.write(buffer, id)
	SerializationUtil.write(buffer, version)
	SerializationUtil.write(buffer, merge_mask)
	if merge_mask & (1 << MainProperty.NAME): SerializationUtil.write(buffer, name)
	if merge_mask & (1 << MainProperty.TYPE): SerializationUtil.write(buffer, type)

static func deserialize_from_buffer(buffer: StreamPeerBuffer) -> CardPack:
	var pack := CardPack.new()
	return _deserialize_parent_properties(buffer, pack)
# 反序列化辅助方法
static func _deserialize_parent_properties(buffer: StreamPeerBuffer, pack: CardPack) -> CardPack:
	pack.id = SerializationUtil.read(buffer, TYPE_INT)
	pack.version = SerializationUtil.read(buffer, TYPE_INT)
	pack.merge_mask = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.NAME):
		pack.name = SerializationUtil.read(buffer, TYPE_STRING_NAME)
	if pack.merge_mask & (1 << MainProperty.TYPE):
		pack.type = SerializationUtil.read(buffer, TYPE_INT)
	return pack

static func get_class_name_static() -> StringName:
	return &"CardPack"

func merge(update_pack: CardPack) -> void:
	id = update_pack.id
	version = update_pack.version
	if update_pack.merge_mask & (1 << MainProperty.NAME): name = update_pack.name
	if update_pack.merge_mask & (1 << MainProperty.TYPE): type = update_pack.type

func calculate_delta_mask(old_pack: CardPack) -> int:
	var delta_mask := 0
	if name != old_pack.name:
		delta_mask |= 1 << MainProperty.NAME
	if type != old_pack.type:
		delta_mask |= 1 << MainProperty.TYPE
	return delta_mask

func update_merge_mask() -> void:
	merge_mask = 0
	if name != &"": merge_mask |= 1 << MainProperty.NAME
	if type != 0: merge_mask |= 1 << MainProperty.TYPE
# 增量更新方法
func _update_and_calculate_delta(card: Card) -> void:
	var new_type = GlobalRegistry.get_constant_index(CardType, card.type)
	id = card.id
	merge_mask = 0
	if name != card.name:
		merge_mask |= 1 << MainProperty.NAME
		name = card.name
	if type != new_type:
		merge_mask |= 1 << MainProperty.TYPE
		type = new_type
	version = (version + 1) % VERSION_MAX

func get_id() -> int:
	return id

# 获取当前版本号
func get_version() -> int:
	return version

# 设置版本号（带回绕检查）
func set_version(new_version: int) -> void:
	version = new_version % VERSION_MAX
