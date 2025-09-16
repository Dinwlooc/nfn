extends CardPack
class_name HandCardPack

# 手牌特有属性
var power: int
var cost: int
var suit: int
var modified_power: int
var modified_cost: int

func _init(init_id: int = 0, init_name: StringName = &"", init_type:StringName = GlobalRegistry.get_card_type_name(GlobalConstants.CardType.NULL), 
		init_power: int = 0, init_cost: int = 0, init_suit: int = 0,
		init_modified_power: int = 0, init_modified_cost: int = 0):
	super._init(init_id, init_name, init_type)
	power = init_power
	cost = init_cost
	suit = init_suit
	modified_power = init_modified_power
	modified_cost = init_modified_cost

# 序列化实现
func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	super.serialize_to_buffer(buffer)
	SerializationUtil.write(buffer, power)
	SerializationUtil.write(buffer, cost)
	SerializationUtil.write(buffer, suit)
	SerializationUtil.write(buffer, modified_power)
	SerializationUtil.write(buffer, modified_cost)

# 反序列化实现
static func deserialize_from_buffer(buffer: StreamPeerBuffer) -> TransPack:
	var pack:HandCardPack = HandCardPack.new()
	pack.id = SerializationUtil.read(buffer, TYPE_INT)
	pack.name = SerializationUtil.read(buffer, TYPE_STRING_NAME)
	pack.type = SerializationUtil.read(buffer, TYPE_INT)
	pack.power = SerializationUtil.read(buffer, TYPE_INT)
	pack.cost = SerializationUtil.read(buffer, TYPE_INT)
	pack.suit = SerializationUtil.read(buffer, TYPE_INT)
	pack.modified_power = SerializationUtil.read(buffer, TYPE_INT)
	pack.modified_cost = SerializationUtil.read(buffer, TYPE_INT)
	return pack
