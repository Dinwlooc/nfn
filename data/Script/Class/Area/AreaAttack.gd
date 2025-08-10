extends Area
class_name AreaAttack
	#守区类，是Players类的一个属性。
func settlement()->void:
	if card_pool[0].type=="attack":
		var settlement_damage = card_pool[0].settlement_damage()
		print("结算伤害为：",settlement_damage)
		var settlement_move =  card_pool[0].settlement_move()
		emit_signal(settlement_move,card_pool[0])
	pass
	pass
