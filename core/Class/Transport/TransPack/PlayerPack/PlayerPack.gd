extends ItemPack
class_name PlayerPack

enum MainProperty {
	SEAT_INDEX,
	HP,
	MP,
	AP,
	DISALLOWED_OPERATIONS,
	MODIFIED_HP_MAX,
	MODIFIED_MP_MAX,
	MODIFIED_INIT_AP,
	MODIFIED_DRAW_CARDS_COUNT,
	PEER_ID,
	END
}

const STANDARD_SEAT_INDEX: int = 0
const STANDARD_HP: int = 20
const STANDARD_MP: int = 20
const STANDARD_AP: int = 3
const STANDARD_MODIFIED_HP_MAX: int = 20
const STANDARD_MODIFIED_MP_MAX: int = 20
const STANDARD_MODIFIED_INIT_AP: int = 3
const STANDARD_MODIFIED_DRAW_CARDS_COUNT: int = 2
const STANDARD_PEER_ID: int = 0

var seat_index: int
var HP: int
var MP: int
var AP: int
var disallowed_operations: Array[StringName]
var modified_HP_max: int
var modified_MP_max: int
var modified_init_AP: int
var modified_draw_cards_count: int
var peer_id: int

static func init_from_player(player: Player) -> PlayerPack:
	return PlayerPack.new(
		player.player_id,
		player.seat_index,
		player.HP,
		player.MP,
		player.AP,
		player.disallowed_operations,
		player.get_attribute(&"HP_max"),
		player.get_attribute(&"MP_max"),
		player.get_attribute(&"init_AP"),
		player.get_attribute(&"draw_cards_count"),
		player.peer_id
	)

func _init(
	init_id: int = 0,
	init_seat_index: int = STANDARD_SEAT_INDEX,
	init_HP: int = STANDARD_HP,
	init_MP: int = STANDARD_MP,
	init_AP: int = STANDARD_AP,
	init_disallowed_operations: Array[StringName] = [],
	init_modified_HP_max: int = STANDARD_MODIFIED_HP_MAX,
	init_modified_MP_max: int = STANDARD_MODIFIED_MP_MAX,
	init_modified_init_AP: int = STANDARD_MODIFIED_INIT_AP,
	init_modified_draw_cards_count: int = STANDARD_MODIFIED_DRAW_CARDS_COUNT,
	init_peer_id: int = STANDARD_PEER_ID
) -> void:
	super._init(init_id)
	seat_index = init_seat_index
	HP = init_HP
	MP = init_MP
	AP = init_AP
	disallowed_operations = init_disallowed_operations.duplicate()
	modified_HP_max = init_modified_HP_max
	modified_MP_max = init_modified_MP_max
	modified_init_AP = init_modified_init_AP
	modified_draw_cards_count = init_modified_draw_cards_count
	peer_id = init_peer_id

func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	super.serialize_to_buffer(buffer)
	if merge_mask & (1 << MainProperty.SEAT_INDEX): SerializationUtil.write(buffer, seat_index)
	if merge_mask & (1 << MainProperty.HP): SerializationUtil.write(buffer, HP)
	if merge_mask & (1 << MainProperty.MP): SerializationUtil.write(buffer, MP)
	if merge_mask & (1 << MainProperty.AP): SerializationUtil.write(buffer, AP)
	if merge_mask & (1 << MainProperty.DISALLOWED_OPERATIONS): SerializationUtil.write(buffer, disallowed_operations)
	if merge_mask & (1 << MainProperty.MODIFIED_HP_MAX): SerializationUtil.write(buffer, modified_HP_max)
	if merge_mask & (1 << MainProperty.MODIFIED_MP_MAX): SerializationUtil.write(buffer, modified_MP_max)
	if merge_mask & (1 << MainProperty.MODIFIED_INIT_AP): SerializationUtil.write(buffer, modified_init_AP)
	if merge_mask & (1 << MainProperty.MODIFIED_DRAW_CARDS_COUNT): SerializationUtil.write(buffer, modified_draw_cards_count)
	if merge_mask & (1 << MainProperty.PEER_ID): SerializationUtil.write(buffer, peer_id)

static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack: TransPack = NULL_PACK) -> PlayerPack:
	if pack == NULL_PACK:
		pack = PlayerPack.new()
	super.deserialize_from_buffer(buffer, pack)
	if pack.merge_mask & (1 << MainProperty.SEAT_INDEX):
		pack.seat_index = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.HP):
		pack.HP = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.MP):
		pack.MP = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.AP):
		pack.AP = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.DISALLOWED_OPERATIONS):
		pack.disallowed_operations = SerializationUtil.read(buffer, TYPE_ARRAY)
	if pack.merge_mask & (1 << MainProperty.MODIFIED_HP_MAX):
		pack.modified_HP_max = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.MODIFIED_MP_MAX):
		pack.modified_MP_max = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.MODIFIED_INIT_AP):
		pack.modified_init_AP = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.MODIFIED_DRAW_CARDS_COUNT):
		pack.modified_draw_cards_count = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.PEER_ID):
		pack.peer_id = SerializationUtil.read(buffer, TYPE_INT)
	return pack

func merge(update_pack: ItemPack) -> void:
	super.merge(update_pack)
	if update_pack.merge_mask & (1 << MainProperty.SEAT_INDEX): seat_index = update_pack.seat_index
	if update_pack.merge_mask & (1 << MainProperty.HP): HP = update_pack.HP
	if update_pack.merge_mask & (1 << MainProperty.MP): MP = update_pack.MP
	if update_pack.merge_mask & (1 << MainProperty.AP): AP = update_pack.AP
	if update_pack.merge_mask & (1 << MainProperty.DISALLOWED_OPERATIONS): disallowed_operations = update_pack.disallowed_operations.duplicate()
	if update_pack.merge_mask & (1 << MainProperty.MODIFIED_HP_MAX): modified_HP_max = update_pack.modified_HP_max
	if update_pack.merge_mask & (1 << MainProperty.MODIFIED_MP_MAX): modified_MP_max = update_pack.modified_MP_max
	if update_pack.merge_mask & (1 << MainProperty.MODIFIED_INIT_AP): modified_init_AP = update_pack.modified_init_AP
	if update_pack.merge_mask & (1 << MainProperty.MODIFIED_DRAW_CARDS_COUNT): modified_draw_cards_count = update_pack.modified_draw_cards_count
	if update_pack.merge_mask & (1 << MainProperty.PEER_ID): peer_id = update_pack.peer_id

## 重置所有玩家属性为标准态
func reset_to_standard() -> void:
	super.reset_to_standard()
	seat_index = STANDARD_SEAT_INDEX
	HP = STANDARD_HP
	MP = STANDARD_MP
	AP = STANDARD_AP
	disallowed_operations.clear()
	modified_HP_max = STANDARD_MODIFIED_HP_MAX
	modified_MP_max = STANDARD_MODIFIED_MP_MAX
	modified_init_AP = STANDARD_MODIFIED_INIT_AP
	modified_draw_cards_count = STANDARD_MODIFIED_DRAW_CARDS_COUNT
	peer_id = STANDARD_PEER_ID

func calculate_delta_mask(old_pack: PlayerPack) -> int:
	var delta_mask: int = 0
	if seat_index != old_pack.seat_index: delta_mask |= 1 << MainProperty.SEAT_INDEX
	if HP != old_pack.HP: delta_mask |= 1 << MainProperty.HP
	if MP != old_pack.MP: delta_mask |= 1 << MainProperty.MP
	if AP != old_pack.AP: delta_mask |= 1 << MainProperty.AP
	if disallowed_operations != old_pack.disallowed_operations: delta_mask |= 1 << MainProperty.DISALLOWED_OPERATIONS
	if modified_HP_max != old_pack.modified_HP_max: delta_mask |= 1 << MainProperty.MODIFIED_HP_MAX
	if modified_MP_max != old_pack.modified_MP_max: delta_mask |= 1 << MainProperty.MODIFIED_MP_MAX
	if modified_init_AP != old_pack.modified_init_AP: delta_mask |= 1 << MainProperty.MODIFIED_INIT_AP
	if modified_draw_cards_count != old_pack.modified_draw_cards_count: delta_mask |= 1 << MainProperty.MODIFIED_DRAW_CARDS_COUNT
	if peer_id != old_pack.peer_id: delta_mask |= 1 << MainProperty.PEER_ID
	return delta_mask

func update_merge_mask() -> void:
	super.update_merge_mask()
	if is_full_update:
		return
	if seat_index != STANDARD_SEAT_INDEX: merge_mask |= 1 << MainProperty.SEAT_INDEX
	if HP != STANDARD_HP: merge_mask |= 1 << MainProperty.HP
	if MP != STANDARD_MP: merge_mask |= 1 << MainProperty.MP
	if AP != STANDARD_AP: merge_mask |= 1 << MainProperty.AP
	if not disallowed_operations.is_empty(): merge_mask |= 1 << MainProperty.DISALLOWED_OPERATIONS
	if modified_HP_max != STANDARD_MODIFIED_HP_MAX: merge_mask |= 1 << MainProperty.MODIFIED_HP_MAX
	if modified_MP_max != STANDARD_MODIFIED_MP_MAX: merge_mask |= 1 << MainProperty.MODIFIED_MP_MAX
	if modified_init_AP != STANDARD_MODIFIED_INIT_AP: merge_mask |= 1 << MainProperty.MODIFIED_INIT_AP
	if modified_draw_cards_count != STANDARD_MODIFIED_DRAW_CARDS_COUNT: merge_mask |= 1 << MainProperty.MODIFIED_DRAW_CARDS_COUNT
	if peer_id != STANDARD_PEER_ID: merge_mask |= 1 << MainProperty.PEER_ID

func _update_and_calculate_delta(player: Player) -> void:
	merge_mask = 0
	if seat_index != player.seat_index:
		merge_mask |= 1 << MainProperty.SEAT_INDEX
		seat_index = player.seat_index
	if HP != player.HP:
		merge_mask |= 1 << MainProperty.HP
		HP = player.HP
	if MP != player.MP:
		merge_mask |= 1 << MainProperty.MP
		MP = player.MP
	if AP != player.AP:
		merge_mask |= 1 << MainProperty.AP
		AP = player.AP
	if disallowed_operations != player.disallowed_operations:
		merge_mask |= 1 << MainProperty.DISALLOWED_OPERATIONS
		disallowed_operations = player.disallowed_operations.duplicate()
	var new_modified_HP_max: int = player.get_attribute(&"HP_max")
	var new_modified_MP_max: int = player.get_attribute(&"MP_max")
	var new_modified_init_AP: int = player.get_attribute(&"init_AP")
	var new_modified_draw_cards_count: int = player.get_attribute(&"draw_cards_count")
	if modified_HP_max != new_modified_HP_max:
		merge_mask |= 1 << MainProperty.MODIFIED_HP_MAX
		modified_HP_max = new_modified_HP_max
	if modified_MP_max != new_modified_MP_max:
		merge_mask |= 1 << MainProperty.MODIFIED_MP_MAX
		modified_MP_max = new_modified_MP_max
	if modified_init_AP != new_modified_init_AP:
		merge_mask |= 1 << MainProperty.MODIFIED_INIT_AP
		modified_init_AP = new_modified_init_AP
	if modified_draw_cards_count != new_modified_draw_cards_count:
		merge_mask |= 1 << MainProperty.MODIFIED_DRAW_CARDS_COUNT
		modified_draw_cards_count = new_modified_draw_cards_count
	if peer_id != player.peer_id:
		merge_mask |= 1 << MainProperty.PEER_ID
		peer_id = player.peer_id
	version = (version + 1) % VERSION_MAX

static func get_class_name_static() -> StringName:
	return &"PlayerPack"
