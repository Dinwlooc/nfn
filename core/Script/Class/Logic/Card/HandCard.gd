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
