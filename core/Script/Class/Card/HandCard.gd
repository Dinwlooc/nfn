extends Card
class_name HandCard

@export var power:int
@export var cost:int
@export var suit:Suit
enum SubKeys {
	POWER = BaseKeys.END ,
	COST ,
	SUIT ,
	MODIFIED_POWER ,
	MODIFIED_COST ,
	END
}
enum Suit{
	HEART,
	DIAMOND,
	SPADE,
	CLUB,
	VOID,
}

func set_suit(newsuit:Suit)->HandCard:
	suit = newsuit
	return self

func property_to_byte(serialize_data:SerializeData)->void:
	super.property_to_byte(serialize_data)
	serialize_write(SubKeys.POWER, power, serialize_data)
	serialize_write(SubKeys.COST, cost, serialize_data)
	serialize_write(SubKeys.SUIT, suit, serialize_data)
	serialize_write(SubKeys.MODIFIED_POWER, get_attribute(&"power", power), serialize_data)
	serialize_write(SubKeys.MODIFIED_COST, get_attribute(&"cost", cost), serialize_data)

func get_enum_size()->int:
	return SubKeys.END
