## 全局配置：资源包加载、翻译查表与卡表展开。
extends Node

## 调试用资源包清单：包分组名 → 该分组下的资源包名列表
var _debug_packs := {
	&"official": ["default"],
	&"mods": []
}
## 资源包加载器，_ready 时创建
var _loader: ResourcePackLoader
## 资源包重载完成
## @emitter
signal resource_packs_reloaded

## 创建加载器、连接完成信号并加载全部资源包
func _ready() -> void:
	_loader = ResourcePackLoader.new()
	_loader.all_packs_loaded.connect(_on_all_packs_loaded)
	load_all_resource_packs()

## 加载指定分组下的全部资源包（默认分组见 _debug_packs）
## @delegates
func load_all_resource_packs(packs: Dictionary = _debug_packs) -> void:
	_loader.load_all(packs)

## 取翻译文本；资源缺失时原样返回键
func get_translation(key: StringName, lang: StringName = &"Zh_CN") -> String:
	var resource = load_resource(&"translation", lang)
	return resource.get_message(key) if resource else String(key)

## 按卡表配置展开某分组的卡牌路径（同一键重复 count 次）
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

## 取资源包内某类资源的路径
func get_resource_path(res_type: StringName, res_key: StringName) -> String:
	return _loader.get_resource_path(res_type, res_key)

## 加载资源包内资源；不存在时返回 null
## @nullable_pure
func load_resource(res_type: StringName, res_key: StringName) -> Resource:
	var path := get_resource_path(res_type, res_key)
	return load(path) if ResourceLoader.exists(path) else null

## 重载资源包（沿用当前分组）
## @delegates
func reload_resource_packs() -> void:
	load_all_resource_packs()

## 资源包加载完成回调，转发为公开信号
## @emitter
func _on_all_packs_loaded() -> void:
	resource_packs_reloaded.emit()

## 读取配置文件；读取失败返回 null
## @nullable_pure
func _load_config(path: String) -> ConfigFile:
	var config := ConfigFile.new()
	return config if config.load(path) == OK else null
