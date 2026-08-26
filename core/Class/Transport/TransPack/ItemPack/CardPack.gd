## 卡牌数据包，包含卡牌的基础属性（名称、类型、所属玩家 ID）。
extends ItemPack
class_name CardPack
## 主要属性枚举，使用 END 作为继承锚点，供子类枚举扩展。
## @end-inheritance
enum MainProperty {
	NAME,
	TYPE,
	PLAYER_ID,
	END
}
const STANDARD_NAME: StringName = &""
const STANDARD_TYPE: int = GlobalConstants.CardType.NULL
const STANDARD_PLAYER_ID: int = 0
var name: StringName
var type: int
var player_id: int
const ItemType = GlobalConstants.KEY_ITEM_TYPE
const NULL = GlobalConstants.CARD_TYPES[GlobalConstants.CardType.NULL]
## 根据物品实例创建全量数据包（统一工厂方法）。
## @factory
static func init_from_item(item: Item) -> CardPack:
	var card := item as Card
	if card == null:
		return null
	return init_from_card(card)
## 从 Card 对象创建数据包。
## @factory
static func init_from_card(card: Card) -> CardPack:
	return CardPack.new(card.id, card.get_name(), card.type, card.get_owner_id())
## 构造器，初始化所有字段。
## @factory
func _init(init_id: int = 0, init_name: StringName = &"", init_type_name: StringName = NULL, init_player_id: int = 0) -> void:
	super._init(init_id)
	name = init_name
	type = GlobalRegistry.get_constant_index(ItemType, init_type_name)
	player_id = init_player_id
	if name != &"":
		merge_mask |= 1 << MainProperty.NAME
	if type != GlobalConstants.CardType.NULL:
		merge_mask |= 1 << MainProperty.TYPE
	if player_id != 0:
		merge_mask |= 1 << MainProperty.PLAYER_ID
## 序列化自身属性到缓冲区。
## @override @flow-override @side-effect
func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	super.serialize_to_buffer(buffer)
	if merge_mask & (1 << MainProperty.NAME):
		SerializationUtil.write(buffer, name)
	if merge_mask & (1 << MainProperty.TYPE):
		SerializationUtil.write(buffer, type)
	if merge_mask & (1 << MainProperty.PLAYER_ID):
		SerializationUtil.write(buffer, player_id)
## 反序列化自身属性。
## @override @flow-override @side-effect
static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = CardPack.new()) -> CardPack:
	super.deserialize_from_buffer(buffer, pack)
	if pack.merge_mask & (1 << MainProperty.NAME):
		pack.name = SerializationUtil.read(buffer, TYPE_STRING_NAME)
	if pack.merge_mask & (1 << MainProperty.TYPE):
		pack.type = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.PLAYER_ID):
		pack.player_id = SerializationUtil.read(buffer, TYPE_INT)
	return pack
## 合并更新包。
## @override @flow-override @side-effect
func merge(update_pack: ItemPack) -> void:
	super.merge(update_pack)
	if update_pack.merge_mask & (1 << MainProperty.NAME):
		name = update_pack.name
	if update_pack.merge_mask & (1 << MainProperty.TYPE):
		type = update_pack.type
	if update_pack.merge_mask & (1 << MainProperty.PLAYER_ID):
		player_id = update_pack.player_id
## 重置所有属性为标准态。
## @override @flow-override @side-effect
func reset_to_standard() -> void:
	super.reset_to_standard()
	name = STANDARD_NAME
	type = STANDARD_TYPE
	player_id = STANDARD_PLAYER_ID
## 计算与旧包的差异掩码。
## @pure
func calculate_delta_mask(old_pack: CardPack) -> int:
	var delta_mask := 0
	if name != old_pack.name:
		delta_mask |= 1 << MainProperty.NAME
	if type != old_pack.type:
		delta_mask |= 1 << MainProperty.TYPE
	if player_id != old_pack.player_id:
		delta_mask |= 1 << MainProperty.PLAYER_ID
	return delta_mask
## 更新合并掩码，标记与标准值不同的属性。
## @override @flow-override @side-effect
func update_merge_mask() -> void:
	super.update_merge_mask()
	if is_full_update:
		return
	if name != &"":
		merge_mask |= 1 << MainProperty.NAME
	if type != 0:
		merge_mask |= 1 << MainProperty.TYPE
	if player_id != 0:
		merge_mask |= 1 << MainProperty.PLAYER_ID
## 返回类名静态方法。
## @override @pure
static func get_class_name_static() -> StringName:
	return &"CardPack"
## 获取卡牌类型名称。
## @pure
func get_card_type() -> StringName:
	return GlobalRegistry.get_constant_name(ItemType, type)
## 以下为私有方法，按规则置于公开方法之后。
## 根据 Card 更新自身并计算增量掩码（用于缓存增量包）。
## @super @side-effect
func _update_and_calculate_delta(card: Card) -> void:
	merge_mask = 0
	_compare_update_name(card)
	_compare_update_type(card)
	_compare_update_player_id(card)
	version = (version + 1) % VERSION_MAX
## 比较并更新名称。
## @atomic
func _compare_update_name(card: Card) -> void:
	var new_name := card.get_name()
	if name != new_name:
		merge_mask |= 1 << MainProperty.NAME
		name = new_name
## 比较并更新类型。
## @atomic
func _compare_update_type(card: Card) -> void:
	var new_type := GlobalRegistry.get_constant_index(ItemType, card.type)
	if type != new_type:
		merge_mask |= 1 << MainProperty.TYPE
		type = new_type
## 比较并更新玩家 ID。
## @atomic
func _compare_update_player_id(card: Card) -> void:
	var new_player_id := card.get_owner_id()
	if player_id != new_player_id:
		merge_mask |= 1 << MainProperty.PLAYER_ID
		player_id = new_player_id
