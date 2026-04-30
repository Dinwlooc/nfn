extends Card
class_name HandCard

@export var power:int = 3
@export var cost:int = 1
@export var suit:Suit = Suit.VOID
@export var attack_range:int = 1
@export var settlement_damage_bonus:int = 0  # 结算伤害加成，默认0

enum Suit {
	HEART,
	DIAMOND,
	SPADE,
	CLUB,
	VOID,
}

func _init() -> void:
	super._init()
	_init_attribute()

func _init_attribute()->void:
	attributeModifiers.set_base_value(&"power", power)
	attributeModifiers.set_base_value(&"cost", cost)
	attributeModifiers.set_base_value(&"attack_range", attack_range)
	attributeModifiers.set_base_value(&"settlement_damage_bonus", settlement_damage_bonus)

func set_suit(newsuit:Suit)->HandCard:
	suit = newsuit
	return self

func _create_card_pack() -> HandCardPack:
	return HandCardPack.init_from_card(self)

func get_settlement_damage(damage_base:int = -1) -> int:
	if damage_base == -1:
		damage_base = attributeModifiers.get_final_value(&"power")
	attributeModifiers.add_modifier(&"settlement_damage_bonus",
		AttributeModifiers.TYPE_BASE_ADD, &"standard_settlement_damage",
		float(damage_base))
	var settlement_damage = attributeModifiers.get_final_value(&"settlement_damage_bonus")
	attributeModifiers.remove_modifier(&"settlement_damage_bonus",
		AttributeModifiers.TYPE_BASE_ADD, &"standard_settlement_damage")
	return settlement_damage
