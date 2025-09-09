extends BaseSerializer
class_name CardSerializer

enum CardClass{
	NULL,
	HAND,
	CHARACTER,
	END
}
const CardData = RenderPack.CardData
const VERSION = 1  # 添加序列化版本号

# 序列化卡牌对象为字节数组
static func serialize(obj: Card) -> PackedByteArray:
	var buffer = StreamPeerBuffer.new()
	BaseSerializer.write(buffer, VERSION)
	if obj is HandCard:
		BaseSerializer.write(buffer, CardClass.HAND)
		BaseSerializer.write(buffer, obj.id)
		BaseSerializer.write(buffer, obj.name)
		BaseSerializer.write(buffer, obj.type)
		BaseSerializer.write(buffer, obj.power)
		BaseSerializer.write(buffer, obj.cost)
		BaseSerializer.write(buffer, obj.suit)
		BaseSerializer.write(buffer, obj.get_attribute(&"power", obj.power))
		BaseSerializer.write(buffer, obj.get_attribute(&"cost", obj.cost))
	# 在这里添加其他卡牌类型的序列化逻辑
	else:
		BaseSerializer.write(buffer, CardClass.NULL)
		BaseSerializer.write(buffer, obj.id)
		BaseSerializer.write(buffer, obj.name)
		BaseSerializer.write(buffer, obj.type)
	return buffer.data_array

# 从字节数组反序列化为卡牌数据对象
static func deserialize(data: PackedByteArray) -> CardData:
	var buffer = StreamPeerBuffer.new()
	buffer.data_array = data
	var version = BaseSerializer.read(buffer, TYPE_INT)
	var class_type = BaseSerializer.read(buffer, TYPE_INT)
	if class_type == CardClass.HAND:
		var hand_data = RenderPack.HandCardData.new()
		hand_data.id = BaseSerializer.read(buffer, TYPE_INT)
		hand_data.name = BaseSerializer.read(buffer, TYPE_STRING_NAME)
		hand_data.type = BaseSerializer.read(buffer, TYPE_STRING_NAME)
		# 读取手牌特有属性
		hand_data.power = BaseSerializer.read(buffer, TYPE_INT)
		hand_data.cost = BaseSerializer.read(buffer, TYPE_INT)
		hand_data.suit = BaseSerializer.read(buffer, TYPE_INT)
		hand_data.modified_power = BaseSerializer.read(buffer, TYPE_INT)
		hand_data.modified_cost = BaseSerializer.read(buffer, TYPE_INT)
		return hand_data
	var card_data = RenderPack.CardData.new()
	card_data.id = BaseSerializer.read(buffer, TYPE_INT)
	card_data.name = BaseSerializer.read(buffer, TYPE_STRING_NAME)
	card_data.type = BaseSerializer.read(buffer, TYPE_STRING_NAME)
	return card_data

static func serialize_array(cards: Array[Card]) -> PackedByteArray:
	var buffer = StreamPeerBuffer.new()
	BaseSerializer.write(buffer, cards.size())
	for card in cards:
		var card_data = serialize(card)
		BaseSerializer.write(buffer, card_data.size())
		buffer.put_data(card_data)
	return buffer.data_array

# 新增：反序列化为卡牌数据数组
static func deserialize_array(data: PackedByteArray) -> Array[CardData]:
	var buffer = StreamPeerBuffer.new()
	buffer.data_array = data
	var result: Array[CardData] = []
	var array_size = BaseSerializer.read(buffer, TYPE_INT)
	for _i in range(array_size):
		var card_size = BaseSerializer.read(buffer, TYPE_INT)
		var card_data = buffer.get_data(card_size)
		if card_data[0] != OK:
			push_error("Failed to read card data")
			continue
		result.append(deserialize(card_data[1]))
	return result
