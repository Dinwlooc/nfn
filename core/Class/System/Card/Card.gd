extends Resource
class_name Card

## 区域变动信号，在 set_area 数据实际发生变化后发射，携带自身引用
signal area_changed(card: Card)

@export var name: StringName
@export var type: StringName
## 预配置的静态修饰器脚本，初始化时加载至CommandModifiers，重置时恢复
@export var modifiers: Array[Script]
var player: Player
var id: int
var area_name: StringName
var area_player_id: int
var attributeModifiers: AttributeModifiers = AttributeModifiers.new()
var last_pack: CardPack = null
var command_modifiers: CommandModifiers = CommandModifiers.new()
var buff_modifiers: BuffModifiers = BuffModifiers.new(attributeModifiers, command_modifiers)

func _init() -> void:
	_load_exported_modifiers()

func _load_exported_modifiers() -> void:
	command_modifiers.reset()
	for modifier in  modifiers:
		add_modifier(modifier)

func add_modifier(modifier: Script) -> void:
	command_modifiers.add_modifier(modifier)
	modifier.init(self)

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

## 设置卡牌所在区域，仅当区域数据发生真实变化时才更新并发射 area_changed 信号
func set_area(area: Area) -> void:
	var new_area_name: StringName = area.area_name
	var new_area_player_id: int = area.get_player().player_id
	if area_name == new_area_name and area_player_id == new_area_player_id:
		return
	area_name = new_area_name
	area_player_id = new_area_player_id
	area_changed.emit(self)

## 供 CardsManager 在分配 ID 后调用，设置 BuffModifiers 所有者
func set_card_id(new_id: int) -> void:
	id = new_id
	buff_modifiers.set_owner(&"card", id)
