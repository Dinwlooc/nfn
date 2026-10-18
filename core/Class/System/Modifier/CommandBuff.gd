extends Buff
class_name CommandBuff

## 目标命令修饰器容器
var command_modifiers: CommandModifiers
## 本 Buff 挂载的命令修饰器脚本
var modifier_script: Modifier

## 构造：绑定命令修饰器容器与脚本
func _init(p_buff_name: StringName, p_command_modifiers: CommandModifiers, p_modifier_script: Modifier) -> void:
	super._init(p_buff_name)
	command_modifiers = p_command_modifiers
	modifier_script = p_modifier_script

## 应用：把命令修饰器挂入容器
## @hook @override
func on_apply() -> void:
	if modifier_script:
		command_modifiers.add_modifier(modifier_script)

## 移除：从容器摘除命令修饰器
## @hook @override
func on_remove() -> void:
	if modifier_script:
		command_modifiers.remove_modifier(modifier_script)

## 层数变化：归零则移除
## @hook @override
func on_stack_changed(_old: int, new_stack: int) -> void:
	if new_stack <= 0:
		on_remove()
