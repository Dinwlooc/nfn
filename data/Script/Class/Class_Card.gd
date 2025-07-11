extends Resource
class_name Card

@export var name: String #卡牌名，命名规范为 命名空间:牌组_卡牌名 如NFN_default:basic_attack
@export var real_name: String#显示给玩家的卡牌名。
@export var description: String #卡牌描述
@export var type: String  # 卡牌类型，如attack

@export var basic_damage: int
 # 基础威力
@export var basic_cost: int    
# 基础消耗
@export var custom_data:Dictionary
var suit: String

	
func start_status_start():
	pass

func settlement_damage()->int:
	var damage:int = basic_damage
	return damage
	
func settlement_move():
	var area:String = "areaDiscard"
	return area
	
func play_cost():
		var cost = basic_cost
		return cost
		


func set_suit(newsuit:String):
	suit = newsuit
	return self

func is_equal_to(other: Card) -> bool:
	if not other is Card:
		return false
	return (
		self.name == other.name and
		self.real_name == other.real_name and
		self.description == other.description and
		self.type == other.type and
		self.suit == other.suit and
		self.basic_damage == other.basic_damage and
		self.basic_cost == other.basic_cost and
		self.texture_path == other.texture_path
	)
