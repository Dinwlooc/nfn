## 玩家数据包，包含玩家所有状态属性。
extends ItemPack
class_name PlayerPack

## 玩家主要属性枚举，使用 END 作为继承锚点（当前无子类扩展，但保留范式）。
## @end-inherit
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
	MORALE_ATTACK,
	MORALE_DEFENSE,
	MORALE_LEVEL,
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
const STANDARD_MORALE_ATTACK: int = 0
const STANDARD_MORALE_DEFENSE: int = 0
const STANDARD_MORALE_LEVEL: int = 0

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
var morale_attack: int
var morale_defense: int
var morale_level: int

## 根据玩家实例创建数据包，并填充到 pack_overriding（若未提供则新建）。调用父类后填充玩家特有属性。
## @factory @heritage-override
static func init_from_item(item: Item, pack_overriding: ItemPack = PlayerPack.new()) -> PlayerPack:
	var player := item as Player
	if player == null:
		return null
	var base_pack := ItemPack.init_from_item(item, pack_overriding) as PlayerPack
	base_pack.seat_index = player.seat_index
	base_pack.HP = player.HP
	base_pack.MP = player.MP
	base_pack.AP = player.AP
	base_pack.disallowed_operations = player.disallowed_operations.duplicate()
	base_pack.modified_HP_max = player.get_attribute(&"HP_max")
	base_pack.modified_MP_max = player.get_attribute(&"MP_max")
	base_pack.modified_init_AP = player.get_attribute(&"init_AP")
	base_pack.modified_draw_cards_count = player.get_attribute(&"draw_cards_count")
	base_pack.peer_id = player.peer_id
	base_pack.morale_attack = player.morale_attack
	base_pack.morale_defense = player.morale_defense
	base_pack.morale_level = player.morale_level
	base_pack.update_merge_mask()
	return base_pack
## 构造器，初始化所有字段。
## @factory
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
	init_peer_id: int = STANDARD_PEER_ID,
	init_morale_attack: int = STANDARD_MORALE_ATTACK,
	init_morale_defense: int = STANDARD_MORALE_DEFENSE,
	init_morale_level: int = STANDARD_MORALE_LEVEL
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
	morale_attack = init_morale_attack
	morale_defense = init_morale_defense
	morale_level = init_morale_level
## 序列化自身属性。
## @flow-override @side-effect
func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	super.serialize_to_buffer(buffer)
	if merge_mask & (1 << MainProperty.SEAT_INDEX):
		SerializationUtil.write(buffer, seat_index)
	if merge_mask & (1 << MainProperty.HP):
		SerializationUtil.write(buffer, HP)
	if merge_mask & (1 << MainProperty.MP):
		SerializationUtil.write(buffer, MP)
	if merge_mask & (1 << MainProperty.AP):
		SerializationUtil.write(buffer, AP)
	if merge_mask & (1 << MainProperty.DISALLOWED_OPERATIONS):
		SerializationUtil.write(buffer, disallowed_operations)
	if merge_mask & (1 << MainProperty.MODIFIED_HP_MAX):
		SerializationUtil.write(buffer, modified_HP_max)
	if merge_mask & (1 << MainProperty.MODIFIED_MP_MAX):
		SerializationUtil.write(buffer, modified_MP_max)
	if merge_mask & (1 << MainProperty.MODIFIED_INIT_AP):
		SerializationUtil.write(buffer, modified_init_AP)
	if merge_mask & (1 << MainProperty.MODIFIED_DRAW_CARDS_COUNT):
		SerializationUtil.write(buffer, modified_draw_cards_count)
	if merge_mask & (1 << MainProperty.PEER_ID):
		SerializationUtil.write(buffer, peer_id)
	if merge_mask & (1 << MainProperty.MORALE_ATTACK):
		SerializationUtil.write(buffer, morale_attack)
	if merge_mask & (1 << MainProperty.MORALE_DEFENSE):
		SerializationUtil.write(buffer, morale_defense)
	if merge_mask & (1 << MainProperty.MORALE_LEVEL):
		SerializationUtil.write(buffer, morale_level)
## 反序列化自身属性。
## @side-effect @heritage-override
static func deserialize_from_buffer(buffer: StreamPeerBuffer, pack_overriding: TransPack = PlayerPack.new()) -> PlayerPack:
	super.deserialize_from_buffer(buffer, pack_overriding)
	if pack_overriding.merge_mask & (1 << MainProperty.SEAT_INDEX):
		pack_overriding.seat_index = SerializationUtil.read(buffer, TYPE_INT)
	if pack_overriding.merge_mask & (1 << MainProperty.HP):
		pack_overriding.HP = SerializationUtil.read(buffer, TYPE_INT)
	if pack_overriding.merge_mask & (1 << MainProperty.MP):
		pack_overriding.MP = SerializationUtil.read(buffer, TYPE_INT)
	if pack_overriding.merge_mask & (1 << MainProperty.AP):
		pack_overriding.AP = SerializationUtil.read(buffer, TYPE_INT)
	if pack_overriding.merge_mask & (1 << MainProperty.DISALLOWED_OPERATIONS):
		pack_overriding.disallowed_operations = SerializationUtil.read(buffer, TYPE_ARRAY)
	if pack_overriding.merge_mask & (1 << MainProperty.MODIFIED_HP_MAX):
		pack_overriding.modified_HP_max = SerializationUtil.read(buffer, TYPE_INT)
	if pack_overriding.merge_mask & (1 << MainProperty.MODIFIED_MP_MAX):
		pack_overriding.modified_MP_max = SerializationUtil.read(buffer, TYPE_INT)
	if pack_overriding.merge_mask & (1 << MainProperty.MODIFIED_INIT_AP):
		pack_overriding.modified_init_AP = SerializationUtil.read(buffer, TYPE_INT)
	if pack_overriding.merge_mask & (1 << MainProperty.MODIFIED_DRAW_CARDS_COUNT):
		pack_overriding.modified_draw_cards_count = SerializationUtil.read(buffer, TYPE_INT)
	if pack_overriding.merge_mask & (1 << MainProperty.PEER_ID):
		pack_overriding.peer_id = SerializationUtil.read(buffer, TYPE_INT)
	if pack_overriding.merge_mask & (1 << MainProperty.MORALE_ATTACK):
		pack_overriding.morale_attack = SerializationUtil.read(buffer, TYPE_INT)
	if pack_overriding.merge_mask & (1 << MainProperty.MORALE_DEFENSE):
		pack_overriding.morale_defense = SerializationUtil.read(buffer, TYPE_INT)
	if pack_overriding.merge_mask & (1 << MainProperty.MORALE_LEVEL):
		pack_overriding.morale_level = SerializationUtil.read(buffer, TYPE_INT)
	return pack_overriding
## 合并更新包。
## @flow-override @side-effect
func merge(update_pack: ItemPack) -> void:
	super.merge(update_pack)
	if update_pack.merge_mask & (1 << MainProperty.SEAT_INDEX):
		seat_index = update_pack.seat_index
	if update_pack.merge_mask & (1 << MainProperty.HP):
		HP = update_pack.HP
	if update_pack.merge_mask & (1 << MainProperty.MP):
		MP = update_pack.MP
	if update_pack.merge_mask & (1 << MainProperty.AP):
		AP = update_pack.AP
	if update_pack.merge_mask & (1 << MainProperty.DISALLOWED_OPERATIONS):
		disallowed_operations = update_pack.disallowed_operations.duplicate()
	if update_pack.merge_mask & (1 << MainProperty.MODIFIED_HP_MAX):
		modified_HP_max = update_pack.modified_HP_max
	if update_pack.merge_mask & (1 << MainProperty.MODIFIED_MP_MAX):
		modified_MP_max = update_pack.modified_MP_max
	if update_pack.merge_mask & (1 << MainProperty.MODIFIED_INIT_AP):
		modified_init_AP = update_pack.modified_init_AP
	if update_pack.merge_mask & (1 << MainProperty.MODIFIED_DRAW_CARDS_COUNT):
		modified_draw_cards_count = update_pack.modified_draw_cards_count
	if update_pack.merge_mask & (1 << MainProperty.PEER_ID):
		peer_id = update_pack.peer_id
	if update_pack.merge_mask & (1 << MainProperty.MORALE_ATTACK):
		morale_attack = update_pack.morale_attack
	if update_pack.merge_mask & (1 << MainProperty.MORALE_DEFENSE):
		morale_defense = update_pack.morale_defense
	if update_pack.merge_mask & (1 << MainProperty.MORALE_LEVEL):
		morale_level = update_pack.morale_level
## 重置所有属性为标准态。
## @flow-override @side-effect
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
	morale_attack = STANDARD_MORALE_ATTACK
	morale_defense = STANDARD_MORALE_DEFENSE
	morale_level = STANDARD_MORALE_LEVEL
## 计算与旧包的差异掩码。
## @override @pure
func calculate_delta_mask(old_pack: PlayerPack) -> int:
	var delta_mask: int = 0
	if seat_index != old_pack.seat_index:
		delta_mask |= 1 << MainProperty.SEAT_INDEX
	if HP != old_pack.HP:
		delta_mask |= 1 << MainProperty.HP
	if MP != old_pack.MP:
		delta_mask |= 1 << MainProperty.MP
	if AP != old_pack.AP:
		delta_mask |= 1 << MainProperty.AP
	if disallowed_operations != old_pack.disallowed_operations:
		delta_mask |= 1 << MainProperty.DISALLOWED_OPERATIONS
	if modified_HP_max != old_pack.modified_HP_max:
		delta_mask |= 1 << MainProperty.MODIFIED_HP_MAX
	if modified_MP_max != old_pack.modified_MP_max:
		delta_mask |= 1 << MainProperty.MODIFIED_MP_MAX
	if modified_init_AP != old_pack.modified_init_AP:
		delta_mask |= 1 << MainProperty.MODIFIED_INIT_AP
	if modified_draw_cards_count != old_pack.modified_draw_cards_count:
		delta_mask |= 1 << MainProperty.MODIFIED_DRAW_CARDS_COUNT
	if peer_id != old_pack.peer_id:
		delta_mask |= 1 << MainProperty.PEER_ID
	if morale_attack != old_pack.morale_attack:
		delta_mask |= 1 << MainProperty.MORALE_ATTACK
	if morale_defense != old_pack.morale_defense:
		delta_mask |= 1 << MainProperty.MORALE_DEFENSE
	if morale_level != old_pack.morale_level:
		delta_mask |= 1 << MainProperty.MORALE_LEVEL
	return delta_mask
## 更新合并掩码。
## @flow-override @side-effect
func update_merge_mask() -> void:
	super.update_merge_mask()
	if is_full_update:
		return
	if seat_index != STANDARD_SEAT_INDEX:
		merge_mask |= 1 << MainProperty.SEAT_INDEX
	if HP != STANDARD_HP:
		merge_mask |= 1 << MainProperty.HP
	if MP != STANDARD_MP:
		merge_mask |= 1 << MainProperty.MP
	if AP != STANDARD_AP:
		merge_mask |= 1 << MainProperty.AP
	if not disallowed_operations.is_empty():
		merge_mask |= 1 << MainProperty.DISALLOWED_OPERATIONS
	if modified_HP_max != STANDARD_MODIFIED_HP_MAX:
		merge_mask |= 1 << MainProperty.MODIFIED_HP_MAX
	if modified_MP_max != STANDARD_MODIFIED_MP_MAX:
		merge_mask |= 1 << MainProperty.MODIFIED_MP_MAX
	if modified_init_AP != STANDARD_MODIFIED_INIT_AP:
		merge_mask |= 1 << MainProperty.MODIFIED_INIT_AP
	if modified_draw_cards_count != STANDARD_MODIFIED_DRAW_CARDS_COUNT:
		merge_mask |= 1 << MainProperty.MODIFIED_DRAW_CARDS_COUNT
	if peer_id != STANDARD_PEER_ID:
		merge_mask |= 1 << MainProperty.PEER_ID
	if morale_attack != STANDARD_MORALE_ATTACK:
		merge_mask |= 1 << MainProperty.MORALE_ATTACK
	if morale_defense != STANDARD_MORALE_DEFENSE:
		merge_mask |= 1 << MainProperty.MORALE_DEFENSE
	if morale_level != STANDARD_MORALE_LEVEL:
		merge_mask |= 1 << MainProperty.MORALE_LEVEL
## 返回类名静态方法。
## @override @pure
static func get_class_name_static() -> StringName:
	return &"PlayerPack"
## 以下为私有方法。
## 根据玩家实例更新自身并计算增量掩码（用于缓存增量包）。
## @flow-override @side-effect
func _update_and_calculate_delta(player: Player) -> void:
	merge_mask = 0
	_compare_update_seat_index(player)
	_compare_update_HP(player)
	_compare_update_MP(player)
	_compare_update_AP(player)
	_compare_update_disallowed_operations(player)
	_compare_update_modified_HP_max(player)
	_compare_update_modified_MP_max(player)
	_compare_update_modified_init_AP(player)
	_compare_update_modified_draw_cards_count(player)
	_compare_update_peer_id(player)
	_compare_update_morale_attack(player)
	_compare_update_morale_defense(player)
	_compare_update_morale_level(player)
	version = (version + 1) % VERSION_MAX
## 比较并更新座位索引。
## @atomic
func _compare_update_seat_index(player: Player) -> void:
	if seat_index != player.seat_index:
		merge_mask |= 1 << MainProperty.SEAT_INDEX
		seat_index = player.seat_index
## 比较并更新生命值。
## @atomic
func _compare_update_HP(player: Player) -> void:
	if HP != player.HP:
		merge_mask |= 1 << MainProperty.HP
		HP = player.HP
## 比较并更新法力值。
## @atomic
func _compare_update_MP(player: Player) -> void:
	if MP != player.MP:
		merge_mask |= 1 << MainProperty.MP
		MP = player.MP
## 比较并更新行动点。
## @atomic
func _compare_update_AP(player: Player) -> void:
	if AP != player.AP:
		merge_mask |= 1 << MainProperty.AP
		AP = player.AP
## 比较并更新禁用操作列表。
## @atomic
func _compare_update_disallowed_operations(player: Player) -> void:
	if disallowed_operations != player.disallowed_operations:
		merge_mask |= 1 << MainProperty.DISALLOWED_OPERATIONS
		disallowed_operations = player.disallowed_operations.duplicate()
## 比较并更新修正最大生命值。
## @atomic
func _compare_update_modified_HP_max(player: Player) -> void:
	var new_val := player.get_attribute(&"HP_max")
	if modified_HP_max != new_val:
		merge_mask |= 1 << MainProperty.MODIFIED_HP_MAX
		modified_HP_max = new_val
## 比较并更新修正最大法力值。
## @atomic
func _compare_update_modified_MP_max(player: Player) -> void:
	var new_val := player.get_attribute(&"MP_max")
	if modified_MP_max != new_val:
		merge_mask |= 1 << MainProperty.MODIFIED_MP_MAX
		modified_MP_max = new_val
## 比较并更新修正初始行动点。
## @atomic
func _compare_update_modified_init_AP(player: Player) -> void:
	var new_val := player.get_attribute(&"init_AP")
	if modified_init_AP != new_val:
		merge_mask |= 1 << MainProperty.MODIFIED_INIT_AP
		modified_init_AP = new_val
## 比较并更新修正抽牌数量。
## @atomic
func _compare_update_modified_draw_cards_count(player: Player) -> void:
	var new_val := player.get_attribute(&"draw_cards_count")
	if modified_draw_cards_count != new_val:
		merge_mask |= 1 << MainProperty.MODIFIED_DRAW_CARDS_COUNT
		modified_draw_cards_count = new_val
## 比较并更新对等体 ID。
## @atomic
func _compare_update_peer_id(player: Player) -> void:
	if peer_id != player.peer_id:
		merge_mask |= 1 << MainProperty.PEER_ID
		peer_id = player.peer_id
## 比较并更新攻击战意。
## @atomic
func _compare_update_morale_attack(player: Player) -> void:
	if morale_attack != player.morale_attack:
		merge_mask |= 1 << MainProperty.MORALE_ATTACK
		morale_attack = player.morale_attack
## 比较并更新防御战意。
## @atomic
func _compare_update_morale_defense(player: Player) -> void:
	if morale_defense != player.morale_defense:
		merge_mask |= 1 << MainProperty.MORALE_DEFENSE
		morale_defense = player.morale_defense
## 比较并更新战意等级。
## @atomic
func _compare_update_morale_level(player: Player) -> void:
	if morale_level != player.morale_level:
		merge_mask |= 1 << MainProperty.MORALE_LEVEL
		morale_level = player.morale_level
