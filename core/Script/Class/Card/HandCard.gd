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

func serialize_expand(serialized_data:Array)->Array:
	serialized_data.set(SubKeys.POWER,power)
	serialized_data.set(SubKeys.COST,cost)
	serialized_data.set(SubKeys.SUIT,suit)
	serialized_data.set(SubKeys.MODIFIED_POWER,get_attribute(&"power",power))
	serialized_data.set(SubKeys.MODIFIED_COST,get_attribute(&"cost",cost))
	serialized_data = serialize_expand_instance(serialized_data)
	return serialized_data

func get_enum_size()->int:
	return SubKeys.END
