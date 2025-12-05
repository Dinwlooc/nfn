extends TransPack
class_name PlayerPack

## 位掩码常量定义
const MASK_SEAT_INDEX: int = 1 << 0
const MASK_HP_MAX: int = 1 << 1
const MASK_HP: int = 1 << 2
const MASK_MP_MAX: int = 1 << 3
const MASK_MP: int = 1 << 4
const MASK_AP: int = 1 << 5
const MASK_INIT_AP: int = 1 << 6
const MASK_DRAW_CARDS_COUNT: int = 1 << 7
const MASK_DISALLOWED_OPERATIONS: int = 1 << 8
var player_id: int = 0  # 总是传输
var merge_mask: int = 0       # 位掩码标识哪些字段被传输
## 以下字段仅在掩码对应位被设置时才传输
var seat_index: int = -1
var HP_max: int = 0
var HP: int = 0
var MP_max: int = 0
var MP: int = 0
var AP: int = 0
var init_AP: int = 3
var draw_cards_count: int = 2
var disallowed_operations: Array[StringName] = []

## 序列化实现
func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	SerializationUtil.write(buffer, player_id)
	SerializationUtil.write(buffer, merge_mask)
	if merge_mask & MASK_SEAT_INDEX:
		SerializationUtil.write(buffer, seat_index)
	if merge_mask & MASK_HP_MAX:
		SerializationUtil.write(buffer, HP_max)
	if merge_mask & MASK_HP:
		SerializationUtil.write(buffer, HP)
	if merge_mask & MASK_MP_MAX:
		SerializationUtil.write(buffer, MP_max)
	if merge_mask & MASK_MP:
		SerializationUtil.write(buffer, MP)
	if merge_mask & MASK_AP:
		SerializationUtil.write(buffer, AP)
	if merge_mask & MASK_INIT_AP:
		SerializationUtil.write(buffer, init_AP)
	if merge_mask & MASK_DRAW_CARDS_COUNT:
		SerializationUtil.write(buffer, draw_cards_count)
	if merge_mask & MASK_DISALLOWED_OPERATIONS:
		SerializationUtil.write(buffer, disallowed_operations)
## 反序列化实现
static func deserialize_from_buffer(buffer: StreamPeerBuffer) -> PlayerPack:
	var pack = PlayerPack.new()
	pack.player_id = SerializationUtil.read(buffer, TYPE_INT)
	pack.merge_mask = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & MASK_SEAT_INDEX:
		pack.seat_index = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & MASK_HP_MAX:
		pack.HP_max = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & MASK_HP:
		pack.HP = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & MASK_MP_MAX:
		pack.MP_max = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & MASK_MP:
		pack.MP = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & MASK_AP:
		pack.AP = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & MASK_INIT_AP:
		pack.init_AP = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & MASK_DRAW_CARDS_COUNT:
		pack.draw_cards_count = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & MASK_DISALLOWED_OPERATIONS:
		pack.disallowed_operations = SerializationUtil.read(buffer, TYPE_ARRAY)
	return pack

## 合并增量更新的PlayerPack数据
func merge(update_pack: PlayerPack) -> void:
	assert(update_pack.player_id == self.player_id,
		"Player ID mismatch during merge: %d vs %d" % [self.player_id, update_pack.player_id])
	if update_pack.merge_mask & MASK_SEAT_INDEX:
		self.seat_index = update_pack.seat_index
	if update_pack.merge_mask & MASK_HP_MAX:
		self.HP_max = update_pack.HP_max
	if update_pack.merge_mask & MASK_HP:
		self.HP = update_pack.HP
	if update_pack.merge_mask & MASK_MP_MAX:
		self.MP_max = update_pack.MP_max
	if update_pack.merge_mask & MASK_MP:
		self.MP = update_pack.MP
	if update_pack.merge_mask & MASK_AP:
		self.AP = update_pack.AP
	if update_pack.merge_mask & MASK_INIT_AP:
		self.init_AP = update_pack.init_AP
	if update_pack.merge_mask & MASK_DRAW_CARDS_COUNT:
		self.draw_cards_count = update_pack.draw_cards_count
	if update_pack.merge_mask & MASK_DISALLOWED_OPERATIONS:
		# 数组类型直接替换
		self.disallowed_operations = update_pack.disallowed_operations.duplicate()
