extends RefCounted
class_name Player

var peer_id: int = 0       # 对等体ID (0=AI)
var player_id: int = -1     # 玩家ID (唯一标识)
var seat_index: int = -1
var HP: int                # 玩家当前生命
var MP: int                # 玩家当前精神值
var AP: int                # 玩家当前的行动点
var area_hand: AreaHand = AreaHand.new(self)
var area_ability: AreaAbility = AreaAbility.new(self)
var area_defensive: AreaDefence = AreaDefence.new(self)
var attributeModifiers: AttributeModifiers = AttributeModifiers.new()
var disallowed_operations: Array[StringName] = []
var last_pack: PlayerPack = null
var morale_attack: int = 0    # 攻击战意
var morale_defense: int = 0   # 防御战意
static var NULL_PLAYER:Player = Player.new()

func _init() -> void:
	_init_attribute()
	morale_attack = 0
	morale_defense = 0

func _init_attribute() -> void:
	attributeModifiers.set_base_value(&"HP_max", 20)
	attributeModifiers.set_base_value(&"MP_max", 20)
	attributeModifiers.set_base_value(&"init_AP", 3)
	attributeModifiers.set_base_value(&"draw_cards_count", 2)
	attributeModifiers.set_base_value(&"speed", 1)

func apply_health_damage(
	amount: int,
	_mechanism: int,
	_source_id: int,
	_modifiers: PackedInt32Array
) -> void:
	HP = HP - amount

func apply_mental_damage(
	amount: int,
	_mechanism: int,
	_source_id: int,
	_modifiers: PackedInt32Array
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
## 获取手牌上限，基于当前精神值的1/4（向上取整）设置基础值，并返回最终值
func get_hand_limit() -> int:
	var base_limit: int = ceili(float(MP) / 4.0)
	attributeModifiers.set_base_value(&"hand_limit", base_limit)
	return get_attribute(&"hand_limit")
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

## 增加攻击战意
func add_morale_attack(value: int) -> void:
	morale_attack += value

## 增加防御战意
func add_morale_defense(value: int) -> void:
	morale_defense += value

## 增加行动点
func add_ap(amount: int) -> void:
	AP += amount
	if AP < 0:
		AP = 0
## 减少行动点
func sub_ap(amount: int) -> void:
	AP -= amount
	if AP < 0:
		AP = 0
## 设置行动点
func set_ap(value: int) -> void:
	AP = max(0, value)
