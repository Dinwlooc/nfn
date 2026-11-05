## 配置表：单个配置文件解析后的「段 → 键 → 值」只读视图，由 [ConfigTableLoader] 构建
## @record
extends RefCounted
class_name ConfigTable

#=== Variables ===
## 段名 → { 键 → 值 }；内层字典不加类型约束，形状由构建者保证
var sections: Dictionary[StringName, Dictionary] = {}
## 表来源文件路径，仅用于诊断信息
var source_path: String = ""

#=== Public Methods ===
## 构建表；table_sections 的所有权移交给本表（逐项转入强类型成员）
func _init(path: String = "", table_sections: Dictionary = {}) -> void:
	source_path = path
	for section: StringName in table_sections:
		sections[section] = table_sections[section]

## 取整段；段不存在时返回空字典
## @pure
func get_section(section: StringName) -> Dictionary:
	return sections.get(section, {})

## 取单值；键不存在时返回缺省值
## @pure
func get_value(section: StringName, key: StringName, default: Variant = null) -> Variant:
	return get_section(section).get(key, default)

## 键是否存在
## @pure
func has_key(section: StringName, key: StringName) -> bool:
	return get_section(section).has(key)
