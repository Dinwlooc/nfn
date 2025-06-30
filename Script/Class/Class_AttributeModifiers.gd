extends RefCounted
class_name AttributeModifiers

var dic:Dictionary

func create(new_dic:Dictionary):
	dic = new_dic
	return self

func addAttributeModifier(attributeModifier:AttributeModifier)->void:
	if !dic[attributeModifier.attribute]:
		dic[attributeModifier.attribute] = {}
	dic[attributeModifier.attribute][attributeModifier.modifier] = attributeModifier.modify
		#覆盖同属性下同名的属性修饰符，保持其插入顺序不变。作为Buff更新的方法。若没有对应的修饰符，godot会自动创建它。
	pass

func removeAttributeModifier(attribute:String, modifier_name:String)->void:
	if dic[attribute]:
		dic[attribute].erase(modifier_name)
	pass

func modify(attribute:String):
	var data = 0
	for modifier in dic[attribute]:
		data = dic[attribute][modifier].call(data)
	return data

