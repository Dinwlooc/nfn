extends RefCounted
class_name Player

var HP_max: int#玩家生命上限
var HP: int #玩家当前生命
var AP: int #玩家当前的行动点
var id:int = 0
var init_AP:int = 3
var draw_cards_count = 2
var area_hand = AreaHand.new(self)
var area_ability = AreaAbility.new(self)
var attributeModifiers:AttributeModifiers = AttributeModifiers.new()

signal damage_data(damageType:String,amout:int,form:int,to:int,fx)

func _damage(damageType:String,amout:int,to:int,fx = ""):
	emit_signal("damage_data",damageType,amout,id,to,fx)
	pass
	
func set_id(new_id:int)->Player:
	id = new_id
	return self
