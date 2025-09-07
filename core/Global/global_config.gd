extends Node

var _debug_packs:Dictionary[StringName,PackedStringArray] = {
	&"official": PackedStringArray(["default"]),
	&"mods": []
}
var _resource_registry: Dictionary[StringName,Dictionary]
const cards_list_path:String =  "res://cards_load_list.cfg"
signal resource_packs_reloaded

func _ready() -> void:
	# 初始化时加载所有资源包
	load_all_resource_packs()
	load_resource(&"translation", &"Zh_CN")
	
func get_translation(key:StringName,lang:StringName=&"Zh_CN")->String:
	var tran:String = load_resource(&"translation",lang).get_message(key)
	if tran:
		return tran
	return String(key)

func get_cards_list(list_name:StringName = &"default")->Array[String]:
	var config:ConfigFile = _load_config(cards_list_path)
	if config:
		var cards_array:Array[String]
		for card_name:String in config.get_section_keys(list_name):
			var count = config.get_value(list_name, card_name)
			var new_cards_array:Array[String]
			new_cards_array.resize(count)
			new_cards_array.fill(get_resource_path(&"cards",card_name))
			cards_array.append_array(new_cards_array)
		return cards_array as Array[String]
	return []
## 加载所有资源包配置
func load_all_resource_packs(packs:Dictionary[StringName,PackedStringArray] = _debug_packs) -> void:
	clear_registry()
	for pack_name:String in packs[&"official"]:
		var pack_path:String = "res://official/%s" % pack_name
		load_resource_pack(pack_path, pack_name)
	for pack_name:String in packs[&"mods"]:
		var pack_path:String = "res://mods/%s" % pack_name
		load_resource_pack(pack_path, pack_name)

## 加载单个资源包配置
func load_resource_pack(pack_path: String, pack_name: String = "Unknow") -> void:
	# 构建配置文件路径
	var config_path = "%s/resource_config.cfg" % pack_path
	# 检查配置文件是否存在
	if not FileAccess.file_exists(config_path):
		push_error("资源包 '%s' 缺少配置文件: %s" % [pack_name, config_path])
		return
	# 处理所有资源类型部分
	var config:ConfigFile = _load_config(config_path)
	if config:
		for resource_type_str:String in config.get_sections():
			var resource_type: StringName = StringName(resource_type_str)
			if not _resource_registry.has(resource_type):
				_resource_registry[resource_type] = {}
			# 处理当前资源类型的所有键值对
			for resource_key_str in config.get_section_keys(resource_type_str):
				var resource_key: StringName = StringName(resource_key_str)
				var relative_path:String = config.get_value(resource_type_str, resource_key_str)
				var full_path:String = "%s/%s" % [pack_path, relative_path]
				_resource_registry[resource_type][resource_key] = full_path
				print("获取资源路径: [%s] %s -> %s" % [resource_type_str,  resource_key_str, full_path])

## 获取资源路径
func get_resource_path(resource_type: StringName, resource_key: StringName) -> String:
	if not _resource_registry.has(resource_type):
		push_error("请求的资源类型不存在: %s" % String(resource_type))
		return ""   
	if not _resource_registry[resource_type].has(resource_key):
		push_error("资源键 '%s' 在类型 '%s' 中不存在" % [String(resource_key), String(resource_type)])
		return ""
	return _resource_registry[resource_type][resource_key]

## 获取资源路径并预加载
func load_resource(resource_type: StringName, resource_key: StringName) -> Resource:
	var path:String = get_resource_path(resource_type, resource_key)
	if path.is_empty():
		return null 
	var resource = load(path)
	if not resource:
		push_error("加载资源失败: %s" % path)
	return resource

## 清除所有资源配置
func clear_registry() -> void:
	_resource_registry.clear()

## 重新加载所有资源包
func reload_resource_packs() -> void:
	load_all_resource_packs()
	resource_packs_reloaded.emit()

func _load_config(path: String) -> ConfigFile:
	var config := ConfigFile.new()
	var err:Error = config.load(path)
	if err != OK:
		push_error("Config load failed: %s (err %d)" % [path, err])
		return null
	return config
