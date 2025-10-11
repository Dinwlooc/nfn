extends RefCounted
class_name AttributeModifiers

# 常量标记四种算术类型
const TYPE_BASE_ADD = 0       # 基础加减 (加法合并)
const TYPE_BASE_MULTIPLY = 1  # 基础倍率 (加法合并)
const TYPE_FINAL_ADD = 2      # 最终加减 (加法合并)
const TYPE_FINAL_MULTIPLY = 3 # 最终乘算 (乘法合并)
const FINAL_VALUE_INDEX = 4   # 最终值
# 数据结构:
#  combined_values: 属性名(StringName) -> 数组[5](float)
var combined_values:Dictionary[StringName,PackedFloat32Array] = {}
# modifiers_dict: 属性名(StringName) -> 类型(int) -> 修饰器名(StringName) -> 值(float)
var modifiers_dict:Dictionary[StringName,Dictionary] = {}
# 设置属性的基础值（转换为基础加减修饰器）
func set_base_value(attribute: StringName, base_value: int) -> void:
	add_modifier(attribute, TYPE_BASE_ADD, &"base_value", float(base_value))
# 添加修饰器
func add_modifier(attribute: StringName, type: int, modifier_name: StringName, value: float) -> void:
	_ensure_attribute_exists(attribute)
	var rounded_value: float = value
	match type:
		TYPE_BASE_ADD, TYPE_FINAL_ADD:
			rounded_value = round(value)  # 加减类型取整
		TYPE_BASE_MULTIPLY, TYPE_FINAL_MULTIPLY:
			rounded_value = round(value * 100.0) / 100.0  # 比率保留2位小数
	var type_dict = modifiers_dict[attribute]
	if not type_dict.has(type):
		type_dict[type] = {}
	var modifiers_of_type:Dictionary = type_dict[type]
	if  modifiers_of_type.has(modifier_name):
		var old_value:float = modifiers_of_type[modifier_name]
		_update_modifier(attribute, type, modifier_name, old_value, rounded_value)
	else:
		modifiers_of_type[modifier_name] = value
		_apply_modifier(attribute, type, rounded_value)
	if type == TYPE_FINAL_MULTIPLY:
		_recalculate_combined_type(attribute, type)
		_recalculate_final(attribute)
# 删除修饰器（已修改）
func remove_modifier(attribute: StringName, type: int, modifier_name: StringName) -> void:
	if not modifiers_dict.has(attribute):
		return
	var type_dict = modifiers_dict[attribute]
	if not type_dict.has(type):
		return
	var modifiers_of_type = type_dict[type]
	if not modifiers_of_type.has(modifier_name):
		return
	var old_value = modifiers_of_type[modifier_name]
	modifiers_of_type.erase(modifier_name)
	if type == TYPE_FINAL_MULTIPLY:
		_recalculate_combined_type(attribute, type)
		_recalculate_final(attribute)
	else:
		_revert_modifier(attribute, type, old_value)
# 更新修饰器值（已修改）
func _update_modifier(attribute: StringName, type: int, modifier_name: StringName, old_value: float, new_value: float) -> void:
	if type == TYPE_FINAL_MULTIPLY:
		_recalculate_combined_type(attribute, type)
		_recalculate_final(attribute)
		return
	var delta = new_value - old_value
	if abs(delta) < 0.001:  # 忽略微小变化
		return
	if delta > 0:
		_apply_modifier(attribute, type, delta)
	elif delta < 0:
		_revert_modifier(attribute, type, -delta)
# 应用修饰器影响（已优化）
func _apply_modifier(attribute: StringName, type: int, value: float) -> void:
	var values:PackedFloat32Array = combined_values[attribute]
	match type:
		TYPE_BASE_ADD:
			values[type] += value
			values[FINAL_VALUE_INDEX] += value * (1.0 + values[TYPE_BASE_MULTIPLY]) * values[TYPE_FINAL_MULTIPLY]
		TYPE_BASE_MULTIPLY:
			values[type] += value
			values[FINAL_VALUE_INDEX] += values[TYPE_BASE_ADD] * value * values[TYPE_FINAL_MULTIPLY]
		TYPE_FINAL_ADD:
			values[type] += value
			values[FINAL_VALUE_INDEX] += value * values[TYPE_FINAL_MULTIPLY]
# 撤销修饰器影响（已优化）
func _revert_modifier(attribute: StringName, type: int, value: float) -> void:
	var values = combined_values[attribute]
	match type:
		TYPE_BASE_ADD:
			values[type] -= value
			values[FINAL_VALUE_INDEX] -= value * (1.0 + values[TYPE_BASE_MULTIPLY]) * values[TYPE_FINAL_MULTIPLY]
		TYPE_BASE_MULTIPLY:
			values[type] -= value
			values[FINAL_VALUE_INDEX] -= values[TYPE_BASE_ADD] * value * values[TYPE_FINAL_MULTIPLY]
		TYPE_FINAL_ADD:
			values[type] -= value
			values[FINAL_VALUE_INDEX] -= value * values[TYPE_FINAL_MULTIPLY]
# 获取最终值
func get_final_value(attribute: StringName) -> int:
	if combined_values.has(attribute):
		return int(round(combined_values[attribute][FINAL_VALUE_INDEX]))
	return 0
# 确保属性存在
func _ensure_attribute_exists(attribute: StringName) -> void:
	if not modifiers_dict.has(attribute):
		modifiers_dict[attribute] = {0:{},1:{},2:{},3:{}}
		combined_values[attribute] = PackedFloat32Array([0.0, 0.0, 0.0, 1.0, 0.0])
# 重新计算指定类型的合并值
func _recalculate_combined_type(attribute: StringName, type: int) -> void:
	var combined = 0.0
	var type_dict = modifiers_dict[attribute].get(type, {})
	if type == TYPE_FINAL_MULTIPLY:
		combined = 1.0
		for value in type_dict.values():
			combined *= value
	else:
		for value in type_dict.values():
			combined += value
	combined_values[attribute][type] = combined
# 重新计算最终值（使用合并值）
func _recalculate_final(attribute: StringName) -> void:
	var vals = combined_values[attribute]
	var base_val = vals[TYPE_BASE_ADD] * (1.0 + vals[TYPE_BASE_MULTIPLY])
	var final_val = (base_val + vals[TYPE_FINAL_ADD]) * vals[TYPE_FINAL_MULTIPLY]
	vals[FINAL_VALUE_INDEX] = final_val
# 调试方法：完整重新计算所有值
func recalculate_all() -> void:
	for attribute in modifiers_dict:
		# 重新计算所有类型
		for type in range(4):
			if modifiers_dict[attribute].has(type):
				_recalculate_combined_type(attribute, type)
		_recalculate_final(attribute)
