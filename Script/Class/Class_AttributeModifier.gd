extends RefCounted
class_name AttributeModifier

var attribute:String
var modifier:String
var modify:Callable

	
func create(attribute_name:String,modifier_name:String,new_modify:Callable):
	attribute = attribute_name
	modifier = modifier_name
	modify = new_modify
	pass

