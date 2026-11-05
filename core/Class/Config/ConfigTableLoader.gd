## 配置表加载器：扫描某端的配置根目录，解析并合并为表集合
extends RefCounted
class_name ConfigTableLoader

const ConfigTableScript := preload("res://core/Class/Config/ConfigTable.gd")
## 配置文件扩展名
const CONFIG_EXTENSION: String = "cfg"

#=== Public Methods ===
## 按根目录顺序加载某端全部配置表；后列出的根覆盖先生效的值
## @delegates
func load_scope(roots: Array[String]) -> Dictionary[StringName, ConfigTableScript]:
	var raw: Dictionary[StringName, Dictionary] = {}
	var sources: Dictionary[StringName, String] = {}
	for root: String in roots:
		_load_root(root, raw, sources)
	return build_tables(raw, sources)

## 由原始字典构建表对象
## @pure
func build_tables(raw: Dictionary[StringName, Dictionary], sources: Dictionary[StringName, String]) -> Dictionary[StringName, ConfigTableScript]:
	var tables: Dictionary[StringName, ConfigTableScript] = {}
	for table_name: StringName in raw:
		tables[table_name] = ConfigTableScript.new(sources.get(table_name, ""), raw[table_name])
	return tables

#=== Private Methods ===
## 加载单个根目录下的全部配置文件；目录不存在时静默跳过
## @external
func _load_root(root: String, raw: Dictionary[StringName, Dictionary], sources: Dictionary[StringName, String]) -> void:
	if not DirAccess.dir_exists_absolute(root):
		return
	for file_name: String in DirAccess.get_files_at(root):
		if file_name.get_extension() != CONFIG_EXTENSION:
			continue
		_load_file(root.path_join(file_name), raw, sources)

## 解析单个配置文件并合并进原始字典（同名表、同名段按键覆盖）
## @external
func _load_file(path: String, raw: Dictionary[StringName, Dictionary], sources: Dictionary[StringName, String]) -> void:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK:
		push_error("配置表读取失败：%s（错误码 %d）" % [path, error])
		return
	var table_name := StringName(path.get_file().get_basename())
	var sections: Dictionary = raw.get(table_name, {})
	for section_name: String in config.get_sections():
		_merge_section(sections, section_name, config, path)
	raw[table_name] = sections
	sources[table_name] = path

## 把单段的键值合并进段集合；空段告警
## @external
func _merge_section(sections: Dictionary, section_name: String, config: ConfigFile, path: String) -> void:
	var section_key := StringName(section_name)
	var rows: Dictionary = sections.get(section_key, {})
	for key: String in config.get_section_keys(section_name):
		rows[StringName(key)] = config.get_value(section_name, key)
	sections[section_key] = rows
	if rows.is_empty():
		push_warning("配置表段为空：%s 的 [%s]" % [path, section_name])
