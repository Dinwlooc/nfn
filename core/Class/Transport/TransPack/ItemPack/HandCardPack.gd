extends CardPack
class_name HandCardPack

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

## 根据物品实例创建全量数据包（统一工厂方法）
static func init_from_item(item: Item) -> HandCardPack:
	var card := item as Card
	if card == null:
		return null
	return init_from_card(card)

static func init_from_card(card: Card) -> HandCardPack:
	if card is Card:
		return HandCardPack.new(
			card.id,
			card.get_name(),
			card.type,
			card.get_base_power(),
			card.get_base_cost(),
			card.suit,
			card.get_power(),
			card.get_cost()
		)
	return null

func _init(
	init_id: int = 0,
	init_name: StringName = &"",
	init_type: StringName = NULL,
	init_power: int = STANDARD_POWER,
	init_cost: int = STANDARD_COST,
	init_suit: int = STANDARD_SUIT,
	init_modified_power: int = STANDARD_MODIFIED_POWER,
	init_modified_cost: int = STANDARD_MODIFIED_COST
) -> void:
	super._init(init_id, init_name, init_type)
	power = init_power
	cost = init_cost
	suit = init_suit
	modified_power = init_modified_power
	modified_cost = init_modified_cost
	if power != STANDARD_POWER: merge_mask |= 1 << Property.POWER
	if cost != STANDARD_COST: merge_mask |= 1 << Property.COST
	if suit != STANDARD_SUIT: merge_mask |= 1 << Property.SUIT
	if modified_power != STANDARD_MODIFIED_POWER: merge_mask |= 1 << Property.MODIFIED_POWER
	if modified_cost != STANDARD_MODIFIED_COST: merge_mask |= 1 << Property.MODIFIED_COST

func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	super.serialize_to_buffer(buffer)
	if merge_mask & (1 << Property.POWER): SerializationUtil.write(buffer, power)
	if merge_mask & (1 << Property.COST): SerializationUtil.write(buffer, cost)
	if merge_mask & (1 << Property.SUIT): SerializationUtil.write(buffer, suit)
	if merge_mask & (1 << Property.MODIFIED_POWER): SerializationUtil.write(buffer, modified_power)
	if merge_mask & (1 << Property.MODIFIED_COST): SerializationUtil.write(buffer, modified_cost)

static func get_class_name_static() -> StringName:
	return &"HandCardPack"

static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = HandCardPack.new()) -> CardPack:
	super.deserialize_from_buffer(buffer, pack)
	if pack.merge_mask & (1 << Property.POWER):
		pack.power = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << Property.COST):
		pack.cost = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << Property.SUIT):
		pack.suit = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << Property.MODIFIED_POWER):
		pack.modified_power = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << Property.MODIFIED_COST):
		pack.modified_cost = SerializationUtil.read(buffer, TYPE_INT)
	return pack

func merge(update_pack: ItemPack) -> void:
	super.merge(update_pack)
	if not update_pack is HandCardPack:
		return
	var hm := update_pack as HandCardPack
	if hm.merge_mask & (1 << Property.POWER): power = hm.power
	if hm.merge_mask & (1 << Property.COST): cost = hm.cost
	if hm.merge_mask & (1 << Property.SUIT): suit = hm.suit
	if hm.merge_mask & (1 << Property.MODIFIED_POWER): modified_power = hm.modified_power
	if hm.merge_mask & (1 << Property.MODIFIED_COST): modified_cost = hm.modified_cost

## 重置所有手牌属性为标准态（包括父类属性）
func reset_to_standard() -> void:
	super.reset_to_standard()
	power = STANDARD_POWER
	cost = STANDARD_COST
	suit = STANDARD_SUIT
	modified_power = STANDARD_MODIFIED_POWER
	modified_cost = STANDARD_MODIFIED_COST

func calculate_delta_mask(old_pack: CardPack) -> int:
	if not (old_pack is HandCardPack):
		return self.merge_mask
	var delta_mask := super.calculate_delta_mask(old_pack)
	var old := old_pack as HandCardPack
	if power != old.power: delta_mask |= 1 << Property.POWER
	if cost != old.cost: delta_mask |= 1 << Property.COST
	if suit != old.suit: delta_mask |= 1 << Property.SUIT
	if modified_power != old.modified_power: delta_mask |= 1 << Property.MODIFIED_POWER
	if modified_cost != old.modified_cost: delta_mask |= 1 << Property.MODIFIED_COST
	return delta_mask

func update_merge_mask() -> void:
	super.update_merge_mask()
	if is_full_update:
		return
	if power != STANDARD_POWER: merge_mask |= 1 << Property.POWER
	if cost != STANDARD_COST: merge_mask |= 1 << Property.COST
	if suit != STANDARD_SUIT: merge_mask |= 1 << Property.SUIT
	if modified_power != STANDARD_MODIFIED_POWER: merge_mask |= 1 << Property.MODIFIED_POWER
	if modified_cost != STANDARD_MODIFIED_COST: merge_mask |= 1 << Property.MODIFIED_COST

func _update_and_calculate_delta(card: Card) -> void:
	super._update_and_calculate_delta(card)
	if card is not Card:
		return
	if power != card.get_base_power():
		merge_mask |= 1 << Property.POWER
		power = card.get_base_power()
	if cost != card.get_base_cost():
		merge_mask |= 1 << Property.COST
		cost = card.get_base_cost()
	if suit != card.suit:
		merge_mask |= 1 << Property.SUIT
		suit = card.suit
	var new_modified_power: int = card.get_power()
	var new_modified_cost: int = card.get_cost()
	if modified_power != new_modified_power:
		merge_mask |= 1 << Property.MODIFIED_POWER
		modified_power = new_modified_power
	if modified_cost != new_modified_cost:
		merge_mask |= 1 << Property.MODIFIED_COST
		modified_cost = new_modified_cost
