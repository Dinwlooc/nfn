extends Resource
class_name Card

@export var name:StringName
@export var type:StringName
var id:int
var area_name:StringName
var attributeModifiers:AttributeModifiers = AttributeModifiers.new()
var last_pack: CardPack = null

func get_attribute(attribute:StringName) -> int:
	return attributeModifiers.get_final_value(attribute)

func get_pack() -> CardPack:
	var current_pack = _create_card_pack()
	if last_pack == null:
		current_pack.update_merge_mask()
		last_pack = current_pack
		return current_pack
	var delta_mask = current_pack.calculate_delta_mask(last_pack)
	current_pack.merge_mask = delta_mask
	last_pack = current_pack
	return current_pack

func get_full_pack() -> CardPack:
	return _create_card_pack()

func _create_card_pack() -> CardPack:
	return CardPack.new(id, name, type)
