extends Card
class_name HandCard

@export var power:int
@export var cost:int
@export var suit:Suit

enum Suit {
	HEART,
	DIAMOND,
	SPADE,
	CLUB,
	VOID,
}
func _init() -> void:
	call_deferred(&"_init_attribute")

func _init_attribute()->void:
	attributeModifiers.set_base_value(&"power",power)
	attributeModifiers.set_base_value(&"cost",cost)

func set_suit(newsuit:Suit)->HandCard:
	suit = newsuit
	return self
## 全量获取接口
## 创建卡牌包的内部方法
func _create_card_pack() -> HandCardPack:
	return HandCardPack.new(
		id, name, type,
		power, cost, suit,
		get_attribute(&"power"),
		get_attribute(&"cost")
	)
