extends RefCounted
class_name BuffModifiers

## 所属卡牌
var card: Card
## 以Buff名称索引的活跃Buff实例字典
var buffs: Dictionary[StringName, Buff] = {}

func _init(p_card: Card) -> void:
	card = p_card

## 施加Buff：若已存在同名Buff则叠加层数，否则添加新Buff
## @param buff 待施加的Buff实例
## @param check_exist 若为true且已存在同名buff，仅增加层数（忽略传入buff的配置）
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

## 外部减少Buff层数（会受锁定限制）
## @param buff_name 目标Buff名称
## @param stack 要减少的层数，默认1
## @param forced 是否强制移除，忽略锁定状态
## @return 是否成功减少了层数（或被移除）
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

## 获取指定名称的Buff实例，若不存在返回null
func get_buff(buff_name: StringName) -> Buff:
	return buffs.get(buff_name, null)

## 强制移除指定Buff的所有层数
func force_remove_buff(buff_name: StringName) -> void:
	remove_buff(buff_name, 999, true)

## 重置所有Buff：移除所有非固有Buff，将固有Buff的层数恢复至inborn_stack
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

## 内部层数修改接口（供Buff自身调用，无视锁定，确保归零即移除）
## @param buff 目标Buff实例
## @param delta 层数变化量（正数为加，负数为减）
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
