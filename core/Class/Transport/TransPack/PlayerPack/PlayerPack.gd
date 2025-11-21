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
var mask: int = 0       # 位掩码标识哪些字段被传输
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
	SerializationUtil.write(buffer, mask)
	if mask & MASK_SEAT_INDEX:
		SerializationUtil.write(buffer, seat_index)
	if mask & MASK_HP_MAX:
		SerializationUtil.write(buffer, HP_max)
	if mask & MASK_HP:
		SerializationUtil.write(buffer, HP)
	if mask & MASK_MP_MAX:
		SerializationUtil.write(buffer, MP_max)
	if mask & MASK_MP:
		SerializationUtil.write(buffer, MP)
	if mask & MASK_AP:
		SerializationUtil.write(buffer, AP)
	if mask & MASK_INIT_AP:
		SerializationUtil.write(buffer, init_AP)
	if mask & MASK_DRAW_CARDS_COUNT:
		SerializationUtil.write(buffer, draw_cards_count)
	if mask & MASK_DISALLOWED_OPERATIONS:
		SerializationUtil.write(buffer, disallowed_operations)
## 反序列化实现
static func deserialize_from_buffer(buffer: StreamPeerBuffer) -> PlayerPack:
	var pack = PlayerPack.new()
	pack.player_id = SerializationUtil.read(buffer, TYPE_INT)
	pack.mask = SerializationUtil.read(buffer, TYPE_INT)
	if pack.mask & MASK_SEAT_INDEX:
		pack.seat_index = SerializationUtil.read(buffer, TYPE_INT)
	if pack.mask & MASK_HP_MAX:
		pack.HP_max = SerializationUtil.read(buffer, TYPE_INT)
	if pack.mask & MASK_HP:
		pack.HP = SerializationUtil.read(buffer, TYPE_INT)
	if pack.mask & MASK_MP_MAX:
		pack.MP_max = SerializationUtil.read(buffer, TYPE_INT)
	if pack.mask & MASK_MP:
		pack.MP = SerializationUtil.read(buffer, TYPE_INT)
	if pack.mask & MASK_AP:
		pack.AP = SerializationUtil.read(buffer, TYPE_INT)
	if pack.mask & MASK_INIT_AP:
		pack.init_AP = SerializationUtil.read(buffer, TYPE_INT)
	if pack.mask & MASK_DRAW_CARDS_COUNT:
		pack.draw_cards_count = SerializationUtil.read(buffer, TYPE_INT)
	if pack.mask & MASK_DISALLOWED_OPERATIONS:
		pack.disallowed_operations = SerializationUtil.read(buffer, TYPE_ARRAY)
	return pack

## 实用方法：从Player对象创建增量更新包
static func create_from_player(player: Player, changed_mask: int) -> PlayerPack:
	var pack = PlayerPack.new()
	pack.player_id = player.player_id
	pack.mask = changed_mask
	if changed_mask & MASK_SEAT_INDEX:
		pack.seat_index = player.seat_index
	if changed_mask & MASK_HP_MAX:
		pack.HP_max = player.HP_max
	if changed_mask & MASK_HP:
		pack.HP = player.HP
	if changed_mask & MASK_MP_MAX:
		pack.MP_max = player.MP_max
	if changed_mask & MASK_MP:
		pack.MP = player.MP
	if changed_mask & MASK_AP:
		pack.AP = player.AP
	if changed_mask & MASK_INIT_AP:
		pack.init_AP = player.init_AP
	if changed_mask & MASK_DRAW_CARDS_COUNT:
		pack.draw_cards_count = player.draw_cards_count
	if changed_mask & MASK_DISALLOWED_OPERATIONS:
		pack.disallowed_operations = player.disallowed_operations.duplicate()
	return pack
