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

# 统一反序列化
static func deserialize_from_buffer(buffer: StreamPeerBuffer) -> CardPack:
	var pack := HandCardPack.new()
	CardPack. _deserialize_parent_properties(buffer, pack)
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
func merge(update_pack: CardPack) -> void:
	super.merge(update_pack)
	if not update_pack is HandCardPack: 
		return
	var hm := update_pack as HandCardPack
	if hm.merge_mask & (1 << Property.POWER): power = hm.power
	if hm.merge_mask & (1 << Property.COST): cost = hm.cost
	if hm.merge_mask & (1 << Property.SUIT): suit = hm.suit
	if hm.merge_mask & (1 << Property.MODIFIED_POWER): modified_power = hm.modified_power
	if hm.merge_mask & (1 << Property.MODIFIED_COST): modified_cost = hm.modified_cost
