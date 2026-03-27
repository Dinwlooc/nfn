extends ItemPack
class_name CardPack

# 从 ItemPack.MainProperty.END 继续枚举
enum MainProperty {
	NAME ,
	TYPE,
	END  # 子类枚举衔接点
}

# 卡牌特定属性
var name: StringName
var type: int
const ItemType = GlobalConstants.KEY_ITEM_TYPE
const NULL = GlobalConstants.CARD_TYPES[GlobalConstants.CardType.NULL]

# 工厂方法
static func init_from_card(card: Card) -> CardPack:
	return CardPack.new(card.id, card.name, card.type)

# 初始化（调用父类初始化）
func _init(init_id: int = 0, init_name: StringName = &"", init_type_name: StringName = NULL) -> void:
	super._init(init_id)
	name = init_name
	type = GlobalRegistry.get_constant_index(ItemType, init_type_name)
	if name != &"": merge_mask |= 1 << MainProperty.NAME
	if type != GlobalConstants.CardType.NULL: merge_mask |= 1 << MainProperty.TYPE

# 序列化实现（调用父类方法并扩展）
func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	super.serialize_to_buffer(buffer)
	if merge_mask & (1 << MainProperty.NAME): SerializationUtil.write(buffer, name)
	if merge_mask & (1 << MainProperty.TYPE): SerializationUtil.write(buffer, type)

# 反序列化静态方法（调用父类方法）
static func deserialize_from_buffer(buffer: StreamPeerBuffer,pack:TransPack = NULL_PACK) -> CardPack:
	if pack == NULL_PACK:
		pack = CardPack.new()
	super.deserialize_from_buffer(buffer,pack)
	if pack.merge_mask & (1 << MainProperty.NAME):
		pack.name = SerializationUtil.read(buffer, TYPE_STRING_NAME)
	if pack.merge_mask & (1 << MainProperty.TYPE):
		pack.type = SerializationUtil.read(buffer, TYPE_INT)
	return pack

# 合并方法（调用父类方法并扩展）
func merge(update_pack:ItemPack) -> void:
	super.merge(update_pack)
	if update_pack.merge_mask & (1 << MainProperty.NAME): name = update_pack.name
	if update_pack.merge_mask & (1 << MainProperty.TYPE): type = update_pack.type

# 计算差异掩码
func calculate_delta_mask(old_pack: CardPack) -> int:
	var delta_mask := 0
	if name != old_pack.name:
		delta_mask |= 1 << MainProperty.NAME
	if type != old_pack.type:
		delta_mask |= 1 << MainProperty.TYPE
	return delta_mask

func update_merge_mask() -> void:
	super.update_merge_mask()
	if name != &"": merge_mask |= 1 << MainProperty.NAME
	if type != 0: merge_mask |= 1 << MainProperty.TYPE

# 增量更新方法
func _update_and_calculate_delta(card: Card) -> void:
	var new_type = GlobalRegistry.get_constant_index(ItemType, card.type)
	merge_mask = 0
	if name != card.name:
		merge_mask |= 1 << MainProperty.NAME
		name = card.name
	if type != new_type:
		merge_mask |= 1 << MainProperty.TYPE
		type = new_type
	version = (version + 1) % VERSION_MAX

# 获取类名（静态）
static func get_class_name_static() -> StringName:
	return &"CardPack"

func get_card_type()->StringName:
	return GlobalRegistry.get_constant_name(ItemType,type)
