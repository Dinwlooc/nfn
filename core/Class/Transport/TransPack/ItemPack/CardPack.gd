extends ItemPack
class_name CardPack

enum MainProperty {
	NAME,
	TYPE,
	PLAYER_ID,   # 新增：玩家ID
	END
}

## 卡牌名称标准态（空）
const STANDARD_NAME: StringName = &""
## 卡牌类型标准态（NULL 对应数值）
const STANDARD_TYPE: int = GlobalConstants.CardType.NULL
## 玩家ID标准态（0 表示无持有者）
const STANDARD_PLAYER_ID: int = 0

var name: StringName
var type: int
var player_id: int   # 新增：所属玩家ID

const ItemType = GlobalConstants.KEY_ITEM_TYPE
const NULL = GlobalConstants.CARD_TYPES[GlobalConstants.CardType.NULL]

## 根据物品实例创建全量数据包（统一工厂方法）
static func init_from_item(item: Item) -> CardPack:
	var card := item as Card
	if card == null:
		return null
	return init_from_card(card)

static func init_from_card(card: Card) -> CardPack:
	# 从Card获取玩家ID（通过 get_owner_id()）
	return CardPack.new(card.id, card.get_name(), card.type, card.get_owner_id())

func _init(init_id: int = 0, init_name: StringName = &"", init_type_name: StringName = NULL, init_player_id: int = 0) -> void:
	super._init(init_id)
	name = init_name
	type = GlobalRegistry.get_constant_index(ItemType, init_type_name)
	player_id = init_player_id
	if name != &"": merge_mask |= 1 << MainProperty.NAME
	if type != GlobalConstants.CardType.NULL: merge_mask |= 1 << MainProperty.TYPE
	if player_id != 0: merge_mask |= 1 << MainProperty.PLAYER_ID

func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	super.serialize_to_buffer(buffer)
	if merge_mask & (1 << MainProperty.NAME): SerializationUtil.write(buffer, name)
	if merge_mask & (1 << MainProperty.TYPE): SerializationUtil.write(buffer, type)
	if merge_mask & (1 << MainProperty.PLAYER_ID): SerializationUtil.write(buffer, player_id)

static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = CardPack.new()) -> CardPack:
	super.deserialize_from_buffer(buffer, pack)
	if pack.merge_mask & (1 << MainProperty.NAME):
		pack.name = SerializationUtil.read(buffer, TYPE_STRING_NAME)
	if pack.merge_mask & (1 << MainProperty.TYPE):
		pack.type = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.PLAYER_ID):
		pack.player_id = SerializationUtil.read(buffer, TYPE_INT)
	return pack

func merge(update_pack: ItemPack) -> void:
	super.merge(update_pack)
	if update_pack.merge_mask & (1 << MainProperty.NAME): name = update_pack.name
	if update_pack.merge_mask & (1 << MainProperty.TYPE): type = update_pack.type
	if update_pack.merge_mask & (1 << MainProperty.PLAYER_ID): player_id = update_pack.player_id

## 重置卡牌基础属性为标准态
func reset_to_standard() -> void:
	super.reset_to_standard()
	name = STANDARD_NAME
	type = STANDARD_TYPE
	player_id = STANDARD_PLAYER_ID

func calculate_delta_mask(old_pack: CardPack) -> int:
	var delta_mask := 0
	if name != old_pack.name:
		delta_mask |= 1 << MainProperty.NAME
	if type != old_pack.type:
		delta_mask |= 1 << MainProperty.TYPE
	if player_id != old_pack.player_id:
		delta_mask |= 1 << MainProperty.PLAYER_ID
	return delta_mask

func update_merge_mask() -> void:
	super.update_merge_mask()
	if is_full_update:
		return
	if name != &"": merge_mask |= 1 << MainProperty.NAME
	if type != 0: merge_mask |= 1 << MainProperty.TYPE
	if player_id != 0: merge_mask |= 1 << MainProperty.PLAYER_ID

func _update_and_calculate_delta(card: Card) -> void:
	var new_type := GlobalRegistry.get_constant_index(ItemType, card.type)
	var new_player_id := card.get_owner_id()
	merge_mask = 0
	if name != card.get_name():
		merge_mask |= 1 << MainProperty.NAME
		name = card.get_name()
	if type != new_type:
		merge_mask |= 1 << MainProperty.TYPE
		type = new_type
	if player_id != new_player_id:
		merge_mask |= 1 << MainProperty.PLAYER_ID
		player_id = new_player_id
	version = (version + 1) % VERSION_MAX

static func get_class_name_static() -> StringName:
	return &"CardPack"

func get_card_type() -> StringName:
	return GlobalRegistry.get_constant_name(ItemType, type)
