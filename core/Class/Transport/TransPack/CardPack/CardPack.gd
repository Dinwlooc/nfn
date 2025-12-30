extends TransPack
class_name CardPack

enum MainProperty {
	ID,
	NAME,
	TYPE,
	END  # 关键：子类从此处开始扩展
}
# 卡牌基础属性
var id: int
var name: StringName
var type: int
var merge_mask: int = 0
const CardType = GlobalConstants.KEY_CARD_TYPE
const NULL = GlobalConstants.CARD_TYPES[GlobalConstants.CardType.NULL]

static func init_from_card(card: Card) -> CardPack:
	return CardPack.new(card.id, card.name, card.type)

func _init(init_id: int = 0, init_name: StringName = &"", init_type_name: StringName = NULL):
	id = init_id
	name = init_name
	type = GlobalRegistry.get_constant_index(CardType, init_type_name)

# 序列化实现（使用枚举位）
func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	SerializationUtil.write(buffer, merge_mask)  # 使用变长编码
	if merge_mask & (1 << MainProperty.ID): SerializationUtil.write(buffer, id)
	if merge_mask & (1 << MainProperty.NAME): SerializationUtil.write(buffer, name)
	if merge_mask & (1 << MainProperty.TYPE): SerializationUtil.write(buffer, type)
static func deserialize_from_buffer(buffer: StreamPeerBuffer) -> CardPack:
	var pack := CardPack.new()
	return _deserialize_parent_properties(buffer, pack)
# 反序列化辅助方法
static func _deserialize_parent_properties(buffer: StreamPeerBuffer, pack: CardPack) -> CardPack:
	pack.merge_mask = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.ID):
		pack.id = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.NAME):
		pack.name = SerializationUtil.read(buffer, TYPE_STRING_NAME)
	if pack.merge_mask & (1 << MainProperty.TYPE):
		pack.type = SerializationUtil.read(buffer, TYPE_INT)
	return pack
static func get_class_name_static() -> StringName:
	return &"CardPack"
func merge(update_pack: CardPack) -> void:
	if update_pack.merge_mask & (1 << MainProperty.ID): id = update_pack.id
	if update_pack.merge_mask & (1 << MainProperty.NAME): name = update_pack.name
	if update_pack.merge_mask & (1 << MainProperty.TYPE): type = update_pack.type
func calculate_delta_mask(old_pack: CardPack) -> int:
	var delta_mask := 0
	if id != old_pack.id:
		delta_mask |= 1 << MainProperty.ID
	if name != old_pack.name:
		delta_mask |= 1 << MainProperty.NAME
	if type != old_pack.type:
		delta_mask |= 1 << MainProperty.TYPE
	return delta_mask
func update_merge_mask() -> void:
	merge_mask = 0
	if id != 0: merge_mask |= 1 << MainProperty.ID
	if name != &"": merge_mask |= 1 << MainProperty.NAME
	if type != 0: merge_mask |= 1 << MainProperty.TYPE
##：增量更新方法
func _update_and_calculate_delta(card: Card) -> void:
	var new_type = GlobalRegistry.get_constant_index(CardType, card.type)
	merge_mask = 0
	if id != card.id:
		merge_mask |= 1 << MainProperty.ID
		id = card.id
	if name != card.name:
		merge_mask |= 1 << MainProperty.NAME
		name = card.name
	if type != new_type:
		merge_mask |= 1 << MainProperty.TYPE
		type = new_type
