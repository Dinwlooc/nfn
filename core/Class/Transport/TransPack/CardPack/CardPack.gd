extends TransPack
class_name CardPack

# 卡牌基础属性
var id: int
var name: StringName
var type: int

const CardType = GlobalConstants.KEY_CARD_TYPE
const NULL = GlobalConstants.CARD_TYPES[GlobalConstants.CardType.NULL]

func _init(init_id: int = 0, init_name: StringName = &"", init_type_name: StringName = NULL ):
	id = init_id
	name = init_name
	type = GlobalRegistry.get_constant_index(CardType,init_type_name)

# 序列化实现
func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	SerializationUtil.write(buffer, id)
	SerializationUtil.write(buffer, name)
	SerializationUtil.write(buffer, type)

# 反序列化实现
static func deserialize_from_buffer(buffer: StreamPeerBuffer) -> TransPack:
	var pack:CardPack = CardPack.new()
	pack.id = SerializationUtil.read(buffer, TYPE_INT)
	pack.name = SerializationUtil.read(buffer, TYPE_STRING_NAME)
	pack.type = SerializationUtil.read(buffer, TYPE_STRING_NAME)
	return pack
