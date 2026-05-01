extends RefCounted
class_name Player

var peer_id: int = 0
var player_id: int = -1
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
static var NULL_PLAYER: Player = Player.new()

func _init() -> void:
	command_modifiers = CommandModifiers.new()
	buff_modifiers = BuffModifiers.new(attributeModifiers, command_modifiers)
	_init_attribute()
	morale_attack = 0
	morale_defense = 0

## 供 PlayersManager 在分配 ID 后调用，设置 BuffModifiers 所有者
func set_player_id(new_id: int) -> void:
	player_id = new_id
	buff_modifiers.set_owner(&"player", player_id)

func _init_attribute() -> void:
	attributeModifiers.set_base_value(&"HP_max", 20)
	attributeModifiers.set_base_value(&"MP_max", 20)
	attributeModifiers.set_base_value(&"init_AP", 3)
	attributeModifiers.set_base_value(&"draw_cards_count", 2)
	attributeModifiers.set_base_value(&"speed", 1)

func apply_health_damage(amount: int, _mechanism: int, _source_id: int, _modifiers: PackedInt32Array) -> void:
	HP = HP - amount

func apply_mental_damage(amount: int, _mechanism: int, _source_id: int, _modifiers: PackedInt32Array) -> void:
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
	attributeModifiers.set_base_value(&"hand_limit", base_limit)
	return get_attribute(&"hand_limit")

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

func add_morale_defense(value: int) -> void:
	morale_defense += value

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
