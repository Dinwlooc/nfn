extends Node

var _debug_packs := {
	&"official": ["default"],
	&"mods": []
}
var _loader: ResourcePackLoader
signal resource_packs_reloaded

func _ready() -> void:
	_loader = ResourcePackLoader.new()
	_loader.all_packs_loaded.connect(_on_all_packs_loaded)
	load_all_resource_packs()

func load_all_resource_packs(packs: Dictionary = _debug_packs) -> void:
	_loader.load_all(packs)

func get_translation(key: StringName, lang: StringName = &"Zh_CN") -> String:
	var resource = load_resource(&"translation", lang)
	return resource.get_message(key) if resource else String(key)

func get_cards_list(list_name: StringName = &"default") -> PackedStringArray:
	var config = _load_config("res://cards_load_list.cfg")
	if not config:
		return []
	var cards_list: PackedStringArray = []
	for card_key in config.get_section_keys(list_name):
		var count: int = config.get_value(list_name, card_key)
		var card_path := get_resource_path(&"cards", card_key)
		for i in range(count):
			cards_list.append(card_path)
	return cards_list

func get_resource_path(res_type: StringName, res_key: StringName) -> String:
	return _loader.get_resource_path(res_type, res_key)

func load_resource(res_type: StringName, res_key: StringName) -> Resource:
	var path := get_resource_path(res_type, res_key)
	return load(path) if ResourceLoader.exists(path) else null

func reload_resource_packs() -> void:
	load_all_resource_packs()

func _on_all_packs_loaded() -> void:
	resource_packs_reloaded.emit()

func _load_config(path: String) -> ConfigFile:
	var config := ConfigFile.new()
	return config if config.load(path) == OK else null
