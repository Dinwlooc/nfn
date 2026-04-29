extends Buff
class_name CommandBuff

## 关联的Modifier脚本，该脚本需提供静态process方法
var modifier_script: Script

func _init(p_buff_name: StringName, p_card: Card, p_modifier_script: Script) -> void:
	super._init(p_buff_name, p_card)
	modifier_script = p_modifier_script

func on_apply() -> void:
	if modifier_script:
		card.modifiers.append(modifier_script)

func on_remove() -> void:
	if modifier_script:
		card.modifiers.erase(modifier_script)

## 命令Buff的层数变化不影响修饰器脚本的存在性
func on_stack_changed(_old: int, new_stack: int) -> void:
	if new_stack <= 0:
		on_remove()
