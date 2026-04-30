extends Buff
class_name AttributeBuff

var attribute_modifiers: AttributeModifiers
var attribute: StringName
var modifier_type: int
var modifier_name: StringName
var value_per_stack: float

func _init(p_buff_name: StringName, p_attribute_modifiers: AttributeModifiers, p_attribute: StringName, p_modifier_type: int, p_modifier_name: StringName, p_value_per_stack: float) -> void:
	super._init(p_buff_name)
	attribute_modifiers = p_attribute_modifiers
	attribute = p_attribute
	modifier_type = p_modifier_type
	modifier_name = p_modifier_name
	value_per_stack = p_value_per_stack

func on_apply() -> void:
	_apply_total_value()

func on_remove() -> void:
	attribute_modifiers.remove_modifier(attribute, modifier_type, modifier_name)

func on_stack_changed(_old: int, new_stack: int) -> void:
	if new_stack > 0:
		_apply_total_value()
	else:
		attribute_modifiers.remove_modifier(attribute, modifier_type, modifier_name)

func _apply_total_value() -> void:
	var total: float = value_per_stack * stack_count
	attribute_modifiers.add_modifier(attribute, modifier_type, modifier_name, total)
