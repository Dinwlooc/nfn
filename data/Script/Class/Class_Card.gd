@tool
extends Resource
class_name Card

var attributeModifiers:AttributeModifiers = AttributeModifiers.new()
const PREST_INIT:Dictionary = {
	"attack":{
		"power":0,
		"cost":0
	},
	"void":{
		"name": "",
		"type": "void"
	}
}
@export var data:Dictionary = {
		"name": "",
		"type": "",
	}
@export_enum("attack","spell","void") var preset_type:String:
	set(value):
		if Engine.is_editor_hint():
			if value != "void"&&value != "":
				var init = data.duplicate()
				init.merge(PREST_INIT[value])
				init["type"] = value
				data = init
			else:
				data = PREST_INIT[value]
			notify_property_list_changed()
			
func get_attribute(attribute: String) -> int:
	if data.has(attribute):
		return attributeModifiers.modify(attribute,data.get(attribute, 0))
	return 0

func set_suit(newsuit:String):
	data["suit"] = newsuit
	return self
