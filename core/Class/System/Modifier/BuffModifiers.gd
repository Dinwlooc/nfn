extends RefCounted
class_name BuffModifiers

var attribute_modifiers: AttributeModifiers
var command_modifiers: CommandModifiers
var buffs: Dictionary[StringName, Buff] = {}
var owner_type: StringName = &""
var owner_id: int = 0

## 构造函数增加所有者参数
func _init(p_attribute_modifiers: AttributeModifiers, p_command_modifiers: CommandModifiers, p_owner_type: StringName = &"", p_owner_id: int = -1) -> void:
	attribute_modifiers = p_attribute_modifiers
	command_modifiers = p_command_modifiers
	owner_type = p_owner_type
	owner_id = p_owner_id
## 设置所有者（用于 ID 延迟绑定的场景）
func set_owner(p_owner_type: StringName, p_owner_id: int) -> void:
	owner_type = p_owner_type
	owner_id = p_owner_id
## 施加Buff（外部入口）
func add_or_stack_buff(buff: Buff, check_exist: bool = true) -> void:
	var name: StringName = buff.buff_name
	if check_exist and buffs.has(name):
		var existing: Buff = buffs[name]
		var old_stack: int = existing.stack_count
		existing.stack_count += 1
		existing.on_stack_changed(old_stack, existing.stack_count)
		return
	buffs[name] = buff
	buff.on_apply()
## 减少Buff层数（受锁定限制，除非强制）
func remove_buff(buff_name: StringName, stack: int = 1, forced: bool = false) -> bool:
	if not buffs.has(buff_name):
		return false
	var buff: Buff = buffs[buff_name]
	if not forced and not buff.can_remove():
		return false
	var old_stack: int = buff.stack_count
	buff.stack_count -= stack
	if buff.stack_count > 0:
		buff.on_stack_changed(old_stack, buff.stack_count)
	else:
		buff.stack_count = 0
		buff.on_remove()
		buffs.erase(buff_name)
	return true

func get_buff(buff_name: StringName) -> Buff:
	return buffs.get(buff_name, null)

func force_remove_buff(buff_name: StringName) -> void:
	remove_buff(buff_name, 999, true)

## 重置所有Buff：移除无固有层数的Buff，恢复有固有层数的Buff到inborn_stack
func reset_buffs() -> void:
	var all_buffs: Array[Buff] = []
	all_buffs.assign(buffs.values())
	for buff in all_buffs:
		if buff.inborn_stack == 0:
			buff.on_remove()
			buffs.erase(buff.buff_name)
		else:
			buff.on_remove()
			buff.stack_count = buff.inborn_stack
			buff.on_apply()

## 内部层数修改（供Buff自身使用，无视锁定，归零即移除）
func _modify_stack_internal(buff: Buff, delta: int) -> void:
	if delta == 0:
		return
	var old_stack: int = buff.stack_count
	buff.stack_count += delta
	if buff.stack_count <= 0:
		buff.stack_count = 0
		buff.on_remove()
		buffs.erase(buff.buff_name)
	else:
		buff.on_stack_changed(old_stack, buff.stack_count)
