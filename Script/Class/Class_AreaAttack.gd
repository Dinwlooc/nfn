extends Area
class_name AreaAttack
	#守区类，是Players类的一个属性。
func settlement()->void:
	if card_pool[0].type=="attack":
		var settlement_damage = card_pool[0].settlement_damage()
		emit_signal("damage_data","settlement_damage",settlement_damage)
		print("结算伤害为：",settlement_damage)
		var settlement_move =  card_pool[0].settlement_move()
		emit_signal(settlement_move,card_pool[0])
	pass
	#守区结算的方法。
func user_signal()-> void:
	add_user_signal("cost_data", [
	{ "name": "cost", "type": TYPE_INT }
	])
	add_user_signal("move_to_areaHand", [
	{ "name": "card", "type": Card }
	])
	add_user_signal("move_to_areaDiscard", [
	{ "name": "card", "type": Card }
	])
	pass
	
	
	pass
