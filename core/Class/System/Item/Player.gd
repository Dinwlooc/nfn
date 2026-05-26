## 玩家类，存储玩家数据，继承自 Item。
extends Item
class_name Player

static var NULL_PLAYER: Player = Player.new()

var peer_id: int = -1
var seat_index: int = -1
var HP: int
var MP: int
var AP: int
var disallowed_operations: Array[StringName] = []
var last_pack: PlayerPack = null
var morale_attack: int = 0
var morale_defense: int = 0
var morale_level: int = 0

signal morale_attack_increased(amount: int)
signal morale_defense_increased(amount: int)
signal morale_level_changed(new_level: int)
signal morale_cleared()

func _init(player_data: PlayerData = PlayerData.new()) -> void:
	_id = 1
	super._init(player_data)
	_init_runtime_state()

func _init_runtime_state() -> void:
	HP = get_attribute(&"HP_max")
	MP = get_attribute(&"MP_max")
	AP = get_attribute(&"init_AP")

func _get_owner_type() -> StringName:
	return &"player"

func apply_health_damage(amount: int) -> void:
	HP -= amount

func apply_mental_damage(amount: int) -> void:
	MP = max(0, MP - amount)

func recover_to_full() -> void:
	HP = get_attribute(&"HP_max")
	MP = get_attribute(&"MP_max")

func reset_ap() -> void:
	AP = get_attribute(&"init_AP")

func get_hand_limit() -> int:
	var base_limit: int = ceili(float(MP) / 4.0)
	return attributeModifiers.compute_with_temporary_bonus(&"hand_limit", base_limit)

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

func add_morale_attack(value: int) -> void:
	morale_attack += value
	morale_attack_increased.emit(value)

func add_morale_defense(value: int) -> void:
	morale_defense += value
	morale_defense_increased.emit(value)

func set_morale_level(level: int) -> void:
	morale_level = level
	morale_level_changed.emit(level)

func clear_morale() -> void:
	morale_attack = 0
	morale_defense = 0
	morale_cleared.emit()

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
