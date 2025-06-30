extends RefCounted
class_name Player

var HP_max: int#玩家生命上限
var HP: int #玩家当前生命
var AP: int #玩家当前的行动点
var id:int = 0
var areaHand = AreaHand.new().set_player(self)
var areaAbility = AreaAbility.new().set_player(self)
var AP_initial: int #玩家每轮的初始行动点
var NCD_initial:int #玩家每轮的抽牌数
var attributeModifiers:AttributeModifiers = AttributeModifiers.new().create({
	"HP_max":{"base":func(data:int)->int:return (data+20)},
	"AP_initial":{"base":func(data:int)->int:return (data+3)},
	"NCD_initial":{"base":func(data:int)->int:return (data+2)},
})

signal damage_data(damageType:String,amout:int,form:int,to:int,fx)
	
func _damage(damageType:String,amout:int,to:int,fx = ""):
	emit_signal("damage_data",damageType,amout,id,to,fx)
	pass
	
func get_NCD_initial()->int:
	NCD_initial = attributeModifiers.modify("NCD_initial")
	return NCD_initial
