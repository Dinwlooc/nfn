extends RefCounted
class_name AttributeModifier

var attribute:String
var modifier:String
var modify:Callable
var permanent:bool

	
func create(attribute_name:StringName,modifier_name:StringName,new_modify:Callable):
	attribute = attribute_name
	modifier = modifier_name
	modify = new_modify
	pass
