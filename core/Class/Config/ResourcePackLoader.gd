extends RefCounted
class_name ResourcePackLoader

signal pack_loaded(pack_name)
signal all_packs_loaded()

var _registry: Dictionary[StringName,Dictionary] = {}

func load_all(packs: Dictionary) -> void:
	clear_registry()
	_load_pack_set(packs.get(&"official", []), "res://resource/")
	_load_pack_set(packs.get(&"mods", []), "res://mods/")
	all_packs_loaded.emit()

func _load_pack_set(pack_names: Array, base_path: String) -> void:
	for pack_name in pack_names:
		var pack_path := "%s%s" % [base_path, pack_name]
		_load_single_pack(pack_path, pack_name)

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

func get_resource_path(res_type: StringName, res_key: StringName) -> String:
	return _registry.get(res_type, {}).get(res_key, "")

func clear_registry() -> void:
	_registry.clear()

func _load_config(path: String) -> ConfigFile:
	var config := ConfigFile.new()
	return config if config.load(path) == OK else null
