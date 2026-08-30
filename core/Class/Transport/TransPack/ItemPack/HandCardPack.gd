## 手牌数据包，在 CardPack 基础上增加手牌特有属性（基础数值、修正数值、花色）。
extends CardPack
class_name HandCardPack
## 手牌特有属性枚举，继承自 CardPack.MainProperty.END。
## @end_marker
enum Property {
	POWER = CardPack.MainProperty.END,
	COST,
	SUIT,
	MODIFIED_POWER,
	MODIFIED_COST
}
const STANDARD_POWER: int = 3
const STANDARD_MODIFIED_POWER: int = 3
const STANDARD_SUIT: int = 0
const STANDARD_COST: int = 1
const STANDARD_MODIFIED_COST: int = 1
var power: int
var cost: int
var suit: int
var modified_power: int
var modified_cost: int
## 根据卡片实例创建手牌数据包，并填充到 pack_overriding（若未提供则新建）。调用父类后填充手牌特有属性。
## @factory @seam_override
static func init_from_item(item: Item, pack_overriding: ItemPack = HandCardPack.new()) -> HandCardPack:
	var card := item as Card
	if card == null:
		return null
	var base_pack := CardPack.init_from_item(item, pack_overriding) as HandCardPack
	base_pack.power = card.get_base_power()
	base_pack.cost = card.get_base_cost()
	base_pack.suit = card.suit
	base_pack.modified_power = card.get_power()
	base_pack.modified_cost = card.get_cost()
	base_pack.update_merge_mask()
	return base_pack
## 从 Card 对象创建数据包。
## @factory
static func init_from_card(card: Card) -> HandCardPack:
	if card is Card:
		return HandCardPack.new(
			card.id,
			card.get_name(),
			card.type,
			card.get_owner_id(),
			card.get_base_power(),
			card.get_base_cost(),
			card.suit,
			card.get_power(),
			card.get_cost()
		)
	return null
## 构造器，初始化所有字段。
## @factory
func _init(
	init_id: int = 0,
	init_name: StringName = &"",
	init_type: StringName = NULL,
	init_player_id: int = 0,
	init_power: int = STANDARD_POWER,
	init_cost: int = STANDARD_COST,
	init_suit: int = STANDARD_SUIT,
	init_modified_power: int = STANDARD_MODIFIED_POWER,
	init_modified_cost: int = STANDARD_MODIFIED_COST
) -> void:
	super._init(init_id, init_name, init_type, init_player_id)
	power = init_power
	cost = init_cost
	suit = init_suit
	modified_power = init_modified_power
	modified_cost = init_modified_cost
	if power != STANDARD_POWER:
		merge_mask |= 1 << Property.POWER
	if cost != STANDARD_COST:
		merge_mask |= 1 << Property.COST
	if suit != STANDARD_SUIT:
		merge_mask |= 1 << Property.SUIT
	if modified_power != STANDARD_MODIFIED_POWER:
		merge_mask |= 1 << Property.MODIFIED_POWER
	if modified_cost != STANDARD_MODIFIED_COST:
		merge_mask |= 1 << Property.MODIFIED_COST
## 序列化自身属性。
## @chain_override @side_effect
func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	super.serialize_to_buffer(buffer)
	if merge_mask & (1 << Property.POWER):
		SerializationUtil.write(buffer, power)
	if merge_mask & (1 << Property.COST):
		SerializationUtil.write(buffer, cost)
	if merge_mask & (1 << Property.SUIT):
		SerializationUtil.write(buffer, suit)
	if merge_mask & (1 << Property.MODIFIED_POWER):
		SerializationUtil.write(buffer, modified_power)
	if merge_mask & (1 << Property.MODIFIED_COST):
		SerializationUtil.write(buffer, modified_cost)
## 反序列化自身属性。
## @side_effect @seam_override
static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack_overriding: TransPack = HandCardPack.new()) -> HandCardPack:
	super.deserialize_from_buffer(buffer, pack_overriding)
	if pack_overriding.merge_mask & (1 << Property.POWER):
		pack_overriding.power = SerializationUtil.read(buffer, TYPE_INT)
	if pack_overriding.merge_mask & (1 << Property.COST):
		pack_overriding.cost = SerializationUtil.read(buffer, TYPE_INT)
	if pack_overriding.merge_mask & (1 << Property.SUIT):
		pack_overriding.suit = SerializationUtil.read(buffer, TYPE_INT)
	if pack_overriding.merge_mask & (1 << Property.MODIFIED_POWER):
		pack_overriding.modified_power = SerializationUtil.read(buffer, TYPE_INT)
	if pack_overriding.merge_mask & (1 << Property.MODIFIED_COST):
		pack_overriding.modified_cost = SerializationUtil.read(buffer, TYPE_INT)
	return pack_overriding
## 合并更新包（需类型检查）。
## @chain_override @side_effect
func merge(update_pack: ItemPack) -> void:
	super.merge(update_pack)
	if not update_pack is HandCardPack:
		return
	var hm := update_pack as HandCardPack
	if hm.merge_mask & (1 << Property.POWER):
		power = hm.power
	if hm.merge_mask & (1 << Property.COST):
		cost = hm.cost
	if hm.merge_mask & (1 << Property.SUIT):
		suit = hm.suit
	if hm.merge_mask & (1 << Property.MODIFIED_POWER):
		modified_power = hm.modified_power
	if hm.merge_mask & (1 << Property.MODIFIED_COST):
		modified_cost = hm.modified_cost
## 重置所有属性为标准态。
## @chain_override @side_effect
func reset_to_standard() -> void:
	super.reset_to_standard()
	power = STANDARD_POWER
	cost = STANDARD_COST
	suit = STANDARD_SUIT
	modified_power = STANDARD_MODIFIED_POWER
	modified_cost = STANDARD_MODIFIED_COST
## 计算与旧包的差异掩码。
## @override @pure
func calculate_delta_mask(old_pack: CardPack) -> int:
	if not (old_pack is HandCardPack):
		return merge_mask
	var delta_mask := super.calculate_delta_mask(old_pack)
	var old := old_pack as HandCardPack
	if power != old.power:
		delta_mask |= 1 << Property.POWER
	if cost != old.cost:
		delta_mask |= 1 << Property.COST
	if suit != old.suit:
		delta_mask |= 1 << Property.SUIT
	if modified_power != old.modified_power:
		delta_mask |= 1 << Property.MODIFIED_POWER
	if modified_cost != old.modified_cost:
		delta_mask |= 1 << Property.MODIFIED_COST
	return delta_mask
## 更新合并掩码。
## @chain_override @side_effect
func update_merge_mask() -> void:
	super.update_merge_mask()
	if is_full_update:
		return
	if power != STANDARD_POWER:
		merge_mask |= 1 << Property.POWER
	if cost != STANDARD_COST:
		merge_mask |= 1 << Property.COST
	if suit != STANDARD_SUIT:
		merge_mask |= 1 << Property.SUIT
	if modified_power != STANDARD_MODIFIED_POWER:
		merge_mask |= 1 << Property.MODIFIED_POWER
	if modified_cost != STANDARD_MODIFIED_COST:
		merge_mask |= 1 << Property.MODIFIED_COST
## 返回类名静态方法。
## @override @pure
static func get_class_name_static() -> StringName:
	return &"HandCardPack"
## 以下为私有方法。
## 根据 Card 更新自身并计算增量掩码（调用父类后再扩展）。
## @chain_override @side_effect
func _update_and_calculate_delta(card: Card) -> void:
	super._update_and_calculate_delta(card)
	_compare_update_power(card)
	_compare_update_cost(card)
	_compare_update_suit(card)
	_compare_update_modified_power(card)
	_compare_update_modified_cost(card)
## 比较并更新基础力量。
## @atomic
func _compare_update_power(card: Card) -> void:
	var new_power := card.get_base_power()
	if power != new_power:
		merge_mask |= 1 << Property.POWER
		power = new_power
## 比较并更新基础费用。
## @atomic
func _compare_update_cost(card: Card) -> void:
	var new_cost := card.get_base_cost()
	if cost != new_cost:
		merge_mask |= 1 << Property.COST
		cost = new_cost
## 比较并更新花色。
## @atomic
func _compare_update_suit(card: Card) -> void:
	if suit != card.suit:
		merge_mask |= 1 << Property.SUIT
		suit = card.suit
## 比较并更新修正力量。
## @atomic
func _compare_update_modified_power(card: Card) -> void:
	var new_modified_power := card.get_power()
	if modified_power != new_modified_power:
		merge_mask |= 1 << Property.MODIFIED_POWER
		modified_power = new_modified_power
## 比较并更新修正费用。
## @atomic
func _compare_update_modified_cost(card: Card) -> void:
	var new_modified_cost := card.get_cost()
	if modified_cost != new_modified_cost:
		merge_mask |= 1 << Property.MODIFIED_COST
		modified_cost = new_modified_cost
