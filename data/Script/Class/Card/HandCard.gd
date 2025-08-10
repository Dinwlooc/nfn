extends Card
class_name HandCard

@export var power:int
@export var cost:int
@export var suit:Suit
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

func serialize_expand(serialized_data:Dictionary)->Dictionary:
	serialized_data.set("power",power)
	serialized_data.set("cost",cost)
	serialized_data.set("suit",suit)
	serialized_data["modified_power"] = get_attribute(&"power")
	serialized_data["modified_cost"] = get_attribute(&"cost")
	serialized_data = serialize_expand_instance(serialized_data)
	return serialized_data
