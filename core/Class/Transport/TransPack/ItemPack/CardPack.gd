extends ItemPack
class_name CardPack

enum MainProperty {
	NAME,
	TYPE,
	END
}

## 卡牌名称标准态（空）
const STANDARD_NAME: StringName = &""
## 卡牌类型标准态（NULL 对应数值）
const STANDARD_TYPE: int = GlobalConstants.CardType.NULL

var name: StringName
var type: int
const ItemType = GlobalConstants.KEY_ITEM_TYPE
const NULL = GlobalConstants.CARD_TYPES[GlobalConstants.CardType.NULL]

## 根据物品实例创建全量数据包（统一工厂方法）
static func init_from_item(item: Item) -> CardPack:
	var card := item as Card
	if card == null:
		return null
	return init_from_card(card)

static func init_from_card(card: Card) -> CardPack:
	return CardPack.new(card.id, card.get_name(), card.type)

func _init(init_id: int = 0, init_name: StringName = &"", init_type_name: StringName = NULL) -> void:
	super._init(init_id)
	name = init_name
	type = GlobalRegistry.get_constant_index(ItemType, init_type_name)
	if name != &"": merge_mask |= 1 << MainProperty.NAME
	if type != GlobalConstants.CardType.NULL: merge_mask |= 1 << MainProperty.TYPE

func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	super.serialize_to_buffer(buffer)
	if merge_mask & (1 << MainProperty.NAME): SerializationUtil.write(buffer, name)
	if merge_mask & (1 << MainProperty.TYPE): SerializationUtil.write(buffer, type)

static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = NULL_PACK) -> CardPack:
	if pack == NULL_PACK:
		pack = CardPack.new()
	super.deserialize_from_buffer(buffer, pack)
	if pack.merge_mask & (1 << MainProperty.NAME):
		pack.name = SerializationUtil.read(buffer, TYPE_STRING_NAME)
	if pack.merge_mask & (1 << MainProperty.TYPE):
		pack.type = SerializationUtil.read(buffer, TYPE_INT)
	return pack

func merge(update_pack: ItemPack) -> void:
	super.merge(update_pack)
	if update_pack.merge_mask & (1 << MainProperty.NAME): name = update_pack.name
	if update_pack.merge_mask & (1 << MainProperty.TYPE): type = update_pack.type

## 重置卡牌基础属性为标准态
func reset_to_standard() -> void:
	super.reset_to_standard()
	name = STANDARD_NAME
	type = STANDARD_TYPE

func calculate_delta_mask(old_pack: CardPack) -> int:
	var delta_mask := 0
	if name != old_pack.name:
		delta_mask |= 1 << MainProperty.NAME
	if type != old_pack.type:
		delta_mask |= 1 << MainProperty.TYPE
	return delta_mask

func update_merge_mask() -> void:
	super.update_merge_mask()
	if is_full_update:
		return
	if name != &"": merge_mask |= 1 << MainProperty.NAME
	if type != 0: merge_mask |= 1 << MainProperty.TYPE

func _update_and_calculate_delta(card: Card) -> void:
	var new_type := GlobalRegistry.get_constant_index(ItemType, card.type)
	merge_mask = 0
	if name != card.get_name():
		merge_mask |= 1 << MainProperty.NAME
		name = card.get_name()
	if type != new_type:
		merge_mask |= 1 << MainProperty.TYPE
		type = new_type
	version = (version + 1) % VERSION_MAX

static func get_class_name_static() -> StringName:
	return &"CardPack"

func get_card_type() -> StringName:
	return GlobalRegistry.get_constant_name(ItemType, type)
