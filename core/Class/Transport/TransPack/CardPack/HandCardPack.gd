extends CardPack
class_name HandCardPack

# 子类专属枚举（从父类END开始）
enum Property {
	POWER = CardPack.MainProperty.END,  # 自动继承父类偏移
	COST,
	SUIT,
	MODIFIED_POWER,
	MODIFIED_COST
	# 扩展时直接添加新属性
}
var power: int
var cost: int
var suit: int
var modified_power: int
var modified_cost: int

static func init_from_card(card: Card) -> HandCardPack:
	if card is HandCard:
		return HandCardPack.new(
			card.id,
			card.name,
			card.type,
			card.power,
			card.cost,
			card.suit,
			card.get_attribute(&"power"),
			card.get_attribute(&"cost")
		)
	return null

func _init(init_id: int = 0, init_name: StringName = &"", init_type: StringName = NULL,
		init_power: int = 0, init_cost: int = 0, init_suit: int = 0,
		init_modified_power: int = 0, init_modified_cost: int = 0):
	super._init(init_id, init_name, init_type)
	power = init_power
	cost = init_cost
	suit = init_suit
	modified_power = init_modified_power
	modified_cost = init_modified_cost
	if power != 0: merge_mask |= 1 << Property.POWER
	if cost != 0: merge_mask |= 1 << Property.COST
	if suit != 0: merge_mask |= 1 << Property.SUIT
	if modified_power != 0: merge_mask |= 1 << Property.MODIFIED_POWER
	if modified_cost != 0: merge_mask |= 1 << Property.MODIFIED_COST

func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	super.serialize_to_buffer(buffer)
	if merge_mask & (1 << Property.POWER): SerializationUtil.write(buffer, power)
	if merge_mask & (1 << Property.COST): SerializationUtil.write(buffer, cost)
	if merge_mask & (1 << Property.SUIT): SerializationUtil.write(buffer, suit)
	if merge_mask & (1 << Property.MODIFIED_POWER): SerializationUtil.write(buffer, modified_power)
	if merge_mask & (1 << Property.MODIFIED_COST): SerializationUtil.write(buffer, modified_cost)
static func get_class_name_static() -> StringName:
	return &"HandCardPack"
# 统一反序列化
static func deserialize_from_buffer(buffer: StreamPeerBuffer,pack:TransPack = NULL_PACK) -> CardPack:
	if pack == NULL_PACK:
		pack = HandCardPack.new()
	super.deserialize_from_buffer(buffer,pack)
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
# 统一合并方法
func merge(update_pack:ItemPack) -> void:
	super.merge(update_pack)
	if not update_pack is HandCardPack:
		return
	var hm := update_pack as HandCardPack
	if hm.merge_mask & (1 << Property.POWER): power = hm.power
	if hm.merge_mask & (1 << Property.COST): cost = hm.cost
	if hm.merge_mask & (1 << Property.SUIT): suit = hm.suit
	if hm.merge_mask & (1 << Property.MODIFIED_POWER): modified_power = hm.modified_power
	if hm.merge_mask & (1 << Property.MODIFIED_COST): modified_cost = hm.modified_cost

func calculate_delta_mask(old_pack: CardPack) -> int:
	if not (old_pack is HandCardPack):
		return self.merge_mask
	var delta_mask :=  super.calculate_delta_mask(old_pack)
	var hand_old: HandCardPack = old_pack as HandCardPack
	if power != hand_old.power:
		delta_mask |= 1 << Property.POWER
	if cost != hand_old.cost:
		delta_mask |= 1 << Property.COST
	if suit != hand_old.suit:
		delta_mask |= 1 << Property.SUIT
	if modified_power != hand_old.modified_power:
		delta_mask |= 1 << Property.MODIFIED_POWER
	if modified_cost != hand_old.modified_cost:
		delta_mask |= 1 << Property.MODIFIED_COST
	return delta_mask

func update_merge_mask() -> void:
	super.update_merge_mask()  # 先调用父类掩码设置
	if power != 0: merge_mask |= 1 << Property.POWER
	if cost != 0: merge_mask |= 1 << Property.COST
	if suit != 0: merge_mask |= 1 << Property.SUIT
	if modified_power != 0: merge_mask |= 1 << Property.MODIFIED_POWER
	if modified_cost != 0: merge_mask |= 1 << Property.MODIFIED_COST

func _update_and_calculate_delta(card:Card) -> void:
	super._update_and_calculate_delta(card)
	if card is not HandCard:
		return
	if power != card.power:
		merge_mask |= 1 << Property.POWER
		power = card.power
	if cost != card.cost:
		merge_mask |= 1 << Property.COST
		cost = card.cost
	if suit != card.suit:
		merge_mask |= 1 << Property.SUIT
		suit = card.suit
	if modified_power != card.get_attribute(&"power"):
		merge_mask |= 1 << Property.MODIFIED_POWER
		modified_power = card.get_attribute(&"power")
	if modified_cost != card.get_attribute(&"cost"):
		merge_mask |= 1 << Property.MODIFIED_COST
		modified_cost = card.get_attribute(&"cost")
