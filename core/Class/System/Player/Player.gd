## 玩家类，仅存储玩家数据，不包含规则逻辑。
extends RefCounted
class_name Player

var peer_id: int = -1
var player_id: int = 1
var seat_index: int = -1
var HP: int
var MP: int
var AP: int
var attributeModifiers: AttributeModifiers = AttributeModifiers.new()
var command_modifiers: CommandModifiers
var buff_modifiers: BuffModifiers
var disallowed_operations: Array[StringName] = []
var last_pack: PlayerPack = null
var morale_attack: int = 0
var morale_defense: int = 0
var morale_level: int = 0
static var NULL_PLAYER: Player = Player.new()

## 战意变化细粒度信号
signal morale_attack_increased(amount: int)          # 攻击战意增加
signal morale_defense_increased(amount: int)         # 防御战意增加
signal morale_level_changed(new_level: int)          # 战意等级变化
signal morale_cleared()                              # 战意清空（攻击+防御归零）

func _init() -> void:
	command_modifiers = CommandModifiers.new()
	buff_modifiers = BuffModifiers.new(attributeModifiers, command_modifiers)
	_init_attribute()

func set_player_id(new_id: int) -> void:
	player_id = new_id
	buff_modifiers.set_owner(&"player", player_id)

func _init_attribute() -> void:
	attributeModifiers.set_base_value(&"HP_max", 20)
	attributeModifiers.set_base_value(&"MP_max", 20)
	attributeModifiers.set_base_value(&"init_AP", 3)
	attributeModifiers.set_base_value(&"draw_cards_count", 2)
	attributeModifiers.set_base_value(&"speed", 1)

func apply_health_damage(amount: int) -> void:
	HP = HP - amount

func apply_mental_damage(amount: int) -> void:
	MP = max(0, MP - amount)

func get_attribute(attribute: StringName) -> int:
	return attributeModifiers.get_final_value(attribute)

func recover_to_full() -> void:
	HP = get_attribute(&"HP_max")
	MP = get_attribute(&"MP_max")

func reset_ap() -> void:
	AP = get_attribute(&"init_AP")

func get_hand_limit() -> int:
	var base_limit: int = ceili(float(MP) / 4.0)
	return attributeModifiers.compute_with_temporary_bonus(&"hand_limit", base_limit)
## 计算实际充能量，基于基础战意值和充能效益修饰器。
func get_charge_amount(base_morale: int) -> int:
	return attributeModifiers.compute_with_temporary_bonus(&"charge_amount", float(base_morale))

func get_pack() -> PlayerPack:
	if last_pack == null:
		last_pack = _create_player_pack()
		last_pack.update_merge_mask()
	else:
		last_pack._update_and_calculate_delta(self)
	return last_pack

func get_full_pack() -> PlayerPack:
	return _create_player_pack()

func _create_player_pack() -> PlayerPack:
	return PlayerPack.init_from_player(self)

func clear_pack_cache() -> void:
	last_pack = null

## 增加攻击战意
func add_morale_attack(value: int) -> void:
	morale_attack += value
	morale_attack_increased.emit(value)

## 增加防御战意
func add_morale_defense(value: int) -> void:
	morale_defense += value
	morale_defense_increased.emit(value)

## 设置战意等级（不清空攻击/防御战意）
func set_morale_level(level: int) -> void:
	morale_level = level
	morale_level_changed.emit(level)

## 清空攻击与防御战意
func clear_morale() -> void:
	morale_attack = 0
	morale_defense = 0
	morale_cleared.emit()

## 设置攻击与防御战意（通常不单独使用，保留用于恢复）
func set_morale(attack: int, defense: int) -> void:
	morale_attack = attack
	morale_defense = defense

func add_ap(amount: int) -> void:
	AP += amount
	if AP < 0:
		AP = 0

func sub_ap(amount: int) -> void:
	AP -= amount
	if AP < 0:
		AP = 0

func set_ap(value: int) -> void:
	AP = max(0, value)
