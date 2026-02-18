extends RefCounted
class_name Player

var peer_id: int = 0       # 对等体ID (0=AI)
var player_id: int = 0     # 玩家ID (唯一标识)
var seat_index: int = -1
var HP: int                # 玩家当前生命
var MP: int                # 玩家当前精神值
var AP: int                # 玩家当前的行动点
var area_hand: AreaHand = AreaHand.new(self)
var area_ability: AreaAbility = AreaAbility.new(self)
var area_defensive: AreaDefensive = AreaDefensive.new(self)
var attributeModifiers: AttributeModifiers = AttributeModifiers.new()
var disallowed_operations: Array[StringName] = []
var last_pack: PlayerPack = null

func _init() -> void:
	_init_attribute()

func _init_attribute() -> void:
	attributeModifiers.set_base_value(&"HP_max", 20)
	attributeModifiers.set_base_value(&"MP_max", 20)
	attributeModifiers.set_base_value(&"init_AP", 3)
	attributeModifiers.set_base_value(&"draw_cards_count", 2)

func apply_health_damage(
	amount: int,
	mechanism: int,
	source_id: int,
	modifiers: PackedInt32Array
) -> void:
	HP = HP - amount

func apply_mental_damage(
	amount: int,
	mechanism: int,
	source_id: int,
	modifiers: PackedInt32Array
) -> void:
	MP = max(0, MP - amount)

# 获取属性值
func get_attribute(attribute: StringName) -> int:
	return attributeModifiers.get_final_value(attribute)

# 将玩家的HP与MP恢复至上限
func recover_to_full() -> void:
	HP = get_attribute(&"HP_max")
	MP = get_attribute(&"MP_max")
# 将玩家AP设置为其初始值
func reset_ap() -> void:
	AP = get_attribute(&"init_AP")

# 获取玩家包（支持增量更新）
func get_pack() -> PlayerPack:
	if last_pack == null:
		last_pack = _create_player_pack()
		last_pack.update_merge_mask()
	else:
		last_pack._update_and_calculate_delta(self)  # 传入 Player 实例
	return last_pack
# 获取完整玩家包（不进行增量更新）
func get_full_pack() -> PlayerPack:
	return _create_player_pack()
# 创建玩家包
func _create_player_pack() -> PlayerPack:
	return PlayerPack.init_from_player(self)
# 当玩家信息不再需要缓存时使用，以释放增量更新缓存的占用
func clear_pack_cache() -> void:
	last_pack = null

func send_pack(peer_id = MultiplayerPeer.TARGET_PEER_BROADCAST) -> void:
	var pack = get_pack()  # 获取增量包（自动处理缓存）
	# 从常量类中获取玩家区域签名（例如 "players"）
	var area_signature = GlobalConstants.AREA_TYPES[GlobalConstants.AreaType.PLAYERS]
	# 构造 ItemSet 请求并发送，类型签名为 PlayerPack 的静态类名
	RenderRequest.ItemSet.new(
		area_signature,
		PlayerPack.get_class_name_static(),
		[pack],
		player_id
	).send_to_player(peer_id)
