extends RefCounted
class_name Player

var HP_max: int#玩家生命上限
var HP: int #玩家当前生命
var AP: int #玩家当前的行动点
var id:int = 0
var areaHand = AreaHand.new().set_player(self)
var areaAbility = AreaAbility.new().set_player(self)
var data = {
	"init_AP" = 3,
	"NCD" = 2
}
var attributeModifiers:AttributeModifiers = AttributeModifiers.new()

signal damage_data(damageType:String,amout:int,form:int,to:int,fx)
	
func _damage(damageType:String,amout:int,to:int,fx = ""):
	emit_signal("damage_data",damageType,amout,id,to,fx)
	pass
	
func get_attribute(attribute: String) -> int:
	return attributeModifiers.modify(attribute, data.get(attribute, 0))
