extends Resource
class_name Card

@export var name: StringName
@export var type: StringName
## 预配置的静态修饰器脚本，初始化时加载至CommandModifiers，重置时恢复
@export var modifiers: Array[Script]
var player: Player
var id: int
var area_name: StringName
var attributeModifiers: AttributeModifiers = AttributeModifiers.new()
var last_pack: CardPack = null
var command_modifiers: CommandModifiers = CommandModifiers.new()
var buff_modifiers: BuffModifiers = BuffModifiers.new(attributeModifiers, command_modifiers)

func _init() -> void:
	_load_exported_modifiers()

func _load_exported_modifiers() -> void:
	command_modifiers.reset(modifiers)

func add_modifier(modifier: Script) -> void:
	command_modifiers.add_modifier(modifier)

func remove_modifier(modifier: Script) -> void:
	command_modifiers.remove_modifier(modifier)

## 重置卡牌状态：清空命令修饰器并重新加载预配置，重置所有Buff
func reset_card() -> void:
	_load_exported_modifiers()
	buff_modifiers.reset_buffs()

func get_attribute(attribute: StringName) -> int:
	return attributeModifiers.get_final_value(attribute)

func get_pack() -> CardPack:
	if last_pack == null:
		last_pack = _create_card_pack()
		last_pack.update_merge_mask()
	else:
		last_pack._update_and_calculate_delta(self)
	return last_pack

func get_full_pack() -> CardPack:
	return _create_card_pack()

func _create_card_pack() -> CardPack:
	return CardPack.init_from_card(self)

func clear_pack_cache() -> void:
	last_pack = null

func set_player(p_player: Player) -> void:
	player = p_player

func get_player() -> Player:
	return player

func clear_player() -> void:
	player = Player.NULL_PLAYER

func get_owner_id() -> int:
	if not player:
		return -1
	return player.player_id
