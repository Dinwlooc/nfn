extends Buff
class_name CommandBuff

var command_modifiers: CommandModifiers
var modifier_script: Script

func _init(p_buff_name: StringName, p_command_modifiers: CommandModifiers, p_modifier_script: Script) -> void:
	super._init(p_buff_name)
	command_modifiers = p_command_modifiers
	modifier_script = p_modifier_script

func on_apply() -> void:
	if modifier_script:
		command_modifiers.add_modifier(modifier_script)

func on_remove() -> void:
	if modifier_script:
		command_modifiers.remove_modifier(modifier_script)

func on_stack_changed(_old: int, new_stack: int) -> void:
	if new_stack <= 0:
		on_remove()
