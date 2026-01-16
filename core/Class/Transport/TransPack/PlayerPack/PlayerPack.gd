extends TransPack
class_name PlayerPack

enum MainProperty {
	SEAT_INDEX,
	HP_MAX,
	HP,
	MP_MAX,
	MP,
	AP,
	INIT_AP,
	DRAW_CARDS_COUNT,
	DISALLOWED_OPERATIONS,
	END  # 子类枚举衔接点
}

# 玩家属性
var player_id: int
var seat_index: int = -1
var HP_max: int = 0
var HP: int = 0
var MP_max: int = 0
var MP: int = 0
var AP: int = 0
var init_AP: int = 3
var draw_cards_count: int = 2
var disallowed_operations: Array[StringName] = []
var merge_mask: int = 0
const VERSION_MAX: int = 65535

# 从Player对象初始化
static func init_from_player(player: Player) -> PlayerPack:
	var pack = PlayerPack.new()
	pack.player_id = player.player_id
	pack.seat_index = player.seat_index
	pack.HP_max = player.HP_max
	pack.HP = player.HP
	pack.MP_max = player.MP_max
	pack.MP = player.MP
	pack.AP = player.AP
	pack.init_AP = player.init_AP
	pack.draw_cards_count = player.draw_cards_count
	pack.disallowed_operations = player.disallowed_operations.duplicate()
	pack.update_merge_mask()
	return pack

func _init(init_player_id: int = 0):
	player_id = init_player_id

# 序列化实现（使用枚举位）
func serialize_to_buffer(buffer: StreamPeerBuffer) -> void:
	SerializationUtil.write(buffer, player_id)
	SerializationUtil.write(buffer, version)
	SerializationUtil.write(buffer, merge_mask)
	if merge_mask & (1 << MainProperty.SEAT_INDEX):
		SerializationUtil.write(buffer, seat_index)
	if merge_mask & (1 << MainProperty.HP_MAX):
		SerializationUtil.write(buffer, HP_max)
	if merge_mask & (1 << MainProperty.HP):
		SerializationUtil.write(buffer, HP)
	if merge_mask & (1 << MainProperty.MP_MAX):
		SerializationUtil.write(buffer, MP_max)
	if merge_mask & (1 << MainProperty.MP):
		SerializationUtil.write(buffer, MP)
	if merge_mask & (1 << MainProperty.AP):
		SerializationUtil.write(buffer, AP)
	if merge_mask & (1 << MainProperty.INIT_AP):
		SerializationUtil.write(buffer, init_AP)
	if merge_mask & (1 << MainProperty.DRAW_CARDS_COUNT):
		SerializationUtil.write(buffer, draw_cards_count)
	if merge_mask & (1 << MainProperty.DISALLOWED_OPERATIONS):
		SerializationUtil.write(buffer, disallowed_operations)

# 反序列化实现
static func deserialize_from_buffer(buffer: StreamPeerBuffer) -> PlayerPack:
	var pack := PlayerPack.new()
	return _deserialize_parent_properties(buffer, pack)

# 反序列化辅助方法
static func _deserialize_parent_properties(buffer: StreamPeerBuffer, pack: PlayerPack) -> PlayerPack:
	pack.player_id = SerializationUtil.read(buffer, TYPE_INT)
	pack.version = SerializationUtil.read(buffer, TYPE_INT)
	pack.merge_mask = SerializationUtil.read(buffer, TYPE_INT)

	if pack.merge_mask & (1 << MainProperty.SEAT_INDEX):
		pack.seat_index = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.HP_MAX):
		pack.HP_max = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.HP):
		pack.HP = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.MP_MAX):
		pack.MP_max = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.MP):
		pack.MP = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.AP):
		pack.AP = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.INIT_AP):
		pack.init_AP = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.DRAW_CARDS_COUNT):
		pack.draw_cards_count = SerializationUtil.read(buffer, TYPE_INT)
	if pack.merge_mask & (1 << MainProperty.DISALLOWED_OPERATIONS):
		pack.disallowed_operations = SerializationUtil.read(buffer, TYPE_ARRAY)

	return pack

static func get_class_name_static() -> StringName:
	return &"PlayerPack"

# 合并增量更新的PlayerPack数据
func merge(update_pack: PlayerPack) -> void:
	assert(update_pack.player_id == self.player_id,
		"Player ID mismatch during merge: %d vs %d" % [self.player_id, update_pack.player_id])

	player_id = update_pack.player_id
	version = update_pack.version

	if update_pack.merge_mask & (1 << MainProperty.SEAT_INDEX):
		self.seat_index = update_pack.seat_index
	if update_pack.merge_mask & (1 << MainProperty.HP_MAX):
		self.HP_max = update_pack.HP_max
	if update_pack.merge_mask & (1 << MainProperty.HP):
		self.HP = update_pack.HP
	if update_pack.merge_mask & (1 << MainProperty.MP_MAX):
		self.MP_max = update_pack.MP_max
	if update_pack.merge_mask & (1 << MainProperty.MP):
		self.MP = update_pack.MP
	if update_pack.merge_mask & (1 << MainProperty.AP):
		self.AP = update_pack.AP
	if update_pack.merge_mask & (1 << MainProperty.INIT_AP):
		self.init_AP = update_pack.init_AP
	if update_pack.merge_mask & (1 << MainProperty.DRAW_CARDS_COUNT):
		self.draw_cards_count = update_pack.draw_cards_count
	if update_pack.merge_mask & (1 << MainProperty.DISALLOWED_OPERATIONS):
		# 数组类型直接替换
		self.disallowed_operations = update_pack.disallowed_operations.duplicate()

# 计算与旧包的差异掩码
func calculate_delta_mask(old_pack: PlayerPack) -> int:
	var delta_mask := 0
	if seat_index != old_pack.seat_index:
		delta_mask |= 1 << MainProperty.SEAT_INDEX
	if HP_max != old_pack.HP_max:
		delta_mask |= 1 << MainProperty.HP_MAX
	if HP != old_pack.HP:
		delta_mask |= 1 << MainProperty.HP
	if MP_max != old_pack.MP_max:
		delta_mask |= 1 << MainProperty.MP_MAX
	if MP != old_pack.MP:
		delta_mask |= 1 << MainProperty.MP
	if AP != old_pack.AP:
		delta_mask |= 1 << MainProperty.AP
	if init_AP != old_pack.init_AP:
		delta_mask |= 1 << MainProperty.INIT_AP
	if draw_cards_count != old_pack.draw_cards_count:
		delta_mask |= 1 << MainProperty.DRAW_CARDS_COUNT
	if disallowed_operations != old_pack.disallowed_operations:
		delta_mask |= 1 << MainProperty.DISALLOWED_OPERATIONS
	return delta_mask

# 更新合并掩码（基于非默认值）
func update_merge_mask() -> void:
	merge_mask = 0
	if seat_index != -1: merge_mask |= 1 << MainProperty.SEAT_INDEX
	if HP_max != 0: merge_mask |= 1 << MainProperty.HP_MAX
	if HP != 0: merge_mask |= 1 << MainProperty.HP
	if MP_max != 0: merge_mask |= 1 << MainProperty.MP_MAX
	if MP != 0: merge_mask |= 1 << MainProperty.MP
	if AP != 0: merge_mask |= 1 << MainProperty.AP
	if init_AP != 3: merge_mask |= 1 << MainProperty.INIT_AP
	if draw_cards_count != 2: merge_mask |= 1 << MainProperty.DRAW_CARDS_COUNT
	if not disallowed_operations.is_empty(): merge_mask |= 1 << MainProperty.DISALLOWED_OPERATIONS

# 增量更新方法（从Player对象更新）
func _update_and_calculate_delta(player: Player) -> int:
	merge_mask = 0
	var delta_mask := 0

	player_id = player.player_id

	if seat_index != player.seat_index:
		merge_mask |= 1 << MainProperty.SEAT_INDEX
		seat_index = player.seat_index
		delta_mask |= 1 << MainProperty.SEAT_INDEX

	if HP_max != player.HP_max:
		merge_mask |= 1 << MainProperty.HP_MAX
		HP_max = player.HP_max
		delta_mask |= 1 << MainProperty.HP_MAX

	if HP != player.HP:
		merge_mask |= 1 << MainProperty.HP
		HP = player.HP
		delta_mask |= 1 << MainProperty.HP

	if MP_max != player.MP_max:
		merge_mask |= 1 << MainProperty.MP_MAX
		MP_max = player.MP_max
		delta_mask |= 1 << MainProperty.MP_MAX

	if MP != player.MP:
		merge_mask |= 1 << MainProperty.MP
		MP = player.MP
		delta_mask |= 1 << MainProperty.MP

	if AP != player.AP:
		merge_mask |= 1 << MainProperty.AP
		AP = player.AP
		delta_mask |= 1 << MainProperty.AP

	if init_AP != player.init_AP:
		merge_mask |= 1 << MainProperty.INIT_AP
		init_AP = player.init_AP
		delta_mask |= 1 << MainProperty.INIT_AP

	if draw_cards_count != player.draw_cards_count:
		merge_mask |= 1 << MainProperty.DRAW_CARDS_COUNT
		draw_cards_count = player.draw_cards_count
		delta_mask |= 1 << MainProperty.DRAW_CARDS_COUNT

	if disallowed_operations != player.disallowed_operations:
		merge_mask |= 1 << MainProperty.DISALLOWED_OPERATIONS
		disallowed_operations = player.disallowed_operations.duplicate()
		delta_mask |= 1 << MainProperty.DISALLOWED_OPERATIONS

	version = (version + 1) % VERSION_MAX
	return delta_mask

# 获取玩家ID
func get_player_id() -> int:
	return player_id

# 获取当前版本号
func get_version() -> int:
	return version

# 设置版本号（带回绕检查）
func set_version(new_version: int) -> void:
	version = new_version % VERSION_MAX
