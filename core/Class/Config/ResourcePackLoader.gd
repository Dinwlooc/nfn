extends RefCounted
class_name ResourcePackLoader

## 单个资源包加载完成
## @emitter
signal pack_loaded(pack_name)
## 全部资源包加载完成
## @emitter
signal all_packs_loaded()

## 资源表：资源类型 → { 资源键 → 绝对路径 }
var _registry: Dictionary[StringName,Dictionary] = {}

## 按分组加载资源包（official → res://resource/，mods → res://mods/）
## @side_effect @emitter
func load_all(packs: Dictionary) -> void:
	clear_registry()
	_load_pack_set(packs.get(&"official", []), "res://resource/")
	_load_pack_set(packs.get(&"mods", []), "res://mods/")
	all_packs_loaded.emit()

## 加载一个分组下的若干资源包
## @side_effect
func _load_pack_set(pack_names: Array, base_path: String) -> void:
	for pack_name in pack_names:
		var pack_path := "%s%s" % [base_path, pack_name]
		_load_single_pack(pack_path, pack_name)

## 读取单个资源包的 resource_config.cfg 并登记其资源
## @side_effect @emitter
func _load_single_pack(pack_path: String, pack_name: String) -> void:
	var config_path := "%s/resource_config.cfg" % pack_path
	if not FileAccess.file_exists(config_path):
		push_error("Missing resource config: %s" % config_path)
		return
	var config := _load_config(config_path)
	if not config:
		return
	for section in config.get_sections():
		var type_dict = _registry.get(section, {})
		for key in config.get_section_keys(section):
			var rel_path: String = config.get_value(section, key)
			type_dict[key] = "%s/%s" % [pack_path, rel_path]
		_registry[section] = type_dict
	pack_loaded.emit(pack_name)

## 取资源路径；未登记时返回空串
func get_resource_path(res_type: StringName, res_key: StringName) -> String:
	return _registry.get(res_type, {}).get(res_key, "")

## 清空资源表
## @side_effect
func clear_registry() -> void:
	_registry.clear()

## 读取配置文件；失败返回 null
## @nullable_pure
func _load_config(path: String) -> ConfigFile:
	var config := ConfigFile.new()
	return config if config.load(path) == OK else null

