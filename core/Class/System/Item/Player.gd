## 玩家类，存储玩家数据，继承自 Item。
extends Item
class_name Player
## 公共玩家占位实例（id=1），用于无主归属
## @zero_instance
static var PUBLIC_PLAYER: Player = Player.new(PlayerData.new(),true).set_id(1)

## 连接对等体 id（-1 表示本地或未连接）
var peer_id: int = -1
## 座位索引（-1 表示未分配）
var seat_index: int = -1
## 生命值
var HP: int = 0
## 法力值
var MP: int = 0
## 行动点
var AP: int = 0
## 本回合被禁止的操作类型
var disallowed_operations: Array[StringName] = []
## 士气·攻击侧
var morale_attack: int = 0
## 士气·防御侧
var morale_defense: int = 0
## 士气等级
var morale_level: int = 0

## 士气攻击侧增加，携带玩家自身
## @emitter
signal morale_attack_increased(amount: int, player: Player)
## 士气防御侧增加，携带玩家自身
## @emitter
signal morale_defense_increased(amount: int, player: Player)
## 士气等级变更
## @emitter
signal morale_level_changed(new_level: int)
## 士气清空
## @emitter
signal morale_cleared()

## 构造：绑定玩家蓝图，可指定虚拟实例（不创建修饰器）
func _init(player_data: PlayerData = PlayerData.new(),is_virtual:bool = false) -> void:
	super._init(player_data,is_virtual)

## 物品类型标识
static func get_item_type() -> StringName:
	return &"player"

## 扣减生命值（可为负，不做下限保护）
## @side_effect
func apply_health_damage(amount: int) -> void:
	HP -= amount

## 扣减法力值（下限 0）
## @side_effect
func apply_mental_damage(amount: int) -> void:
	MP = max(0, MP - amount)

## 把生命与法力恢复到上限
## @side_effect
func recover_to_full() -> void:
	HP = get_attribute(&"HP_max")
	MP = get_attribute(&"MP_max")

## 把行动点重置为初始值
## @side_effect
func reset_ap() -> void:
	AP = get_attribute(&"init_AP")

## 手牌上限：基础值 = MP/4 向上取整，再叠临时加成
func get_hand_limit() -> int:
	var base_limit: int = ceili(float(MP) / 4.0)
	return attributeModifiers.compute_with_temporary_bonus(&"hand_limit", base_limit)

## 蓄力值：基础士气再叠临时加成
func get_charge_amount(base_morale: int) -> int:
	return attributeModifiers.compute_with_temporary_bonus(&"charge_amount", float(base_morale))

## 清除增量数据包缓存
## @side_effect
func clear_pack_cache() -> void:
	last_pack = null

## 增加士气攻击侧并广播
## @side_effect @emitter
func add_morale_attack(value: int) -> void:
	morale_attack += value
	morale_attack_increased.emit(value, self)

## 增加士气防御侧并广播
## @side_effect @emitter
func add_morale_defense(value: int) -> void:
	morale_defense += value
	morale_defense_increased.emit(value, self)

## 设置士气等级并广播
## @emitter
func set_morale_level(level: int) -> void:
	morale_level = level
	morale_level_changed.emit(level)

## 清空双方士气并广播
## @side_effect @emitter
func clear_morale() -> void:
	morale_attack = 0
	morale_defense = 0
	morale_cleared.emit()

## 直接设定双方士气（不广播）
func set_morale(attack: int, defense: int) -> void:
	morale_attack = attack
	morale_defense = defense

## 增加行动点（下限 0）
## @side_effect
func add_ap(amount: int) -> void:
	AP += amount
	if AP < 0:
		AP = 0

## 扣减行动点（下限 0）
## @side_effect
func sub_ap(amount: int) -> void:
	AP -= amount
	if AP < 0:
		AP = 0

## 设定行动点（下限 0）
func set_ap(value: int) -> void:
	AP = max(0, value)
