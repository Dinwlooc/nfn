extends Node

var _debug_packs: Dictionary = {
	"official": ["default"],
	"mods": []
}
var _resource_registry: Dictionary = {}
const cards_list_path:String =  "res://cards_load_list.cfg"
signal resource_packs_reloaded

func _ready() -> void:
	# 初始化时加载所有资源包
	load_all_resource_packs()

func get_translation(key:String,lang:String="Zh_CN")->String:
	if load_resource("translation",lang)&&load_resource("translation",lang).get_message(key):
		return load_resource("translation",lang).get_message(key)
	return key
	
func get_cards_list(list_name:String = "default")->Array[String]:
	var config:ConfigFile = _load_config(cards_list_path)
	if config:
		var cards_array:Array[String]
		for card_name in config.get_section_keys(list_name):
			var count = config.get_value(list_name, card_name)
			var new_cards_array:Array[String]
			new_cards_array.resize(count)
			new_cards_array.fill(get_resource_path("cards",card_name))
			cards_array.append_array(new_cards_array)
		return cards_array as Array[String]
	return []
## 加载所有资源包配置
func load_all_resource_packs() -> void:
	clear_registry()
	for pack_name in _debug_packs["official"]:
		var pack_path = "res://offical/%s" % pack_name
		load_resource_pack(pack_path, pack_name)
	for pack_name in _debug_packs["mods"]:
		var pack_path = "res://mods/%s" % pack_name
		load_resource_pack(pack_path, pack_name)

## 加载单个资源包配置
func load_resource_pack(pack_path: String, pack_name: String) -> void:
	# 构建配置文件路径
	var config_path = "%s/resource_config.cfg" % pack_path
	# 检查配置文件是否存在
	if not FileAccess.file_exists(config_path):
		push_error("资源包 '%s' 缺少配置文件: %s" % [pack_name, config_path])
		return
	# 处理所有资源类型部分
	var config:ConfigFile = _load_config(config_path)
	if config:
		for resource_type in config.get_sections():
			# 跳过特殊部分
			if not _resource_registry.has(resource_type):
				_resource_registry[resource_type] = {}
			# 处理当前资源类型的所有键值对
			for resource_key in config.get_section_keys(resource_type):
				var relative_path = config.get_value(resource_type, resource_key)
				var full_path = "%s/%s" % [pack_path, relative_path]
				_resource_registry[resource_type][resource_key] = full_path
				print("获取资源路径: [%s] %s -> %s" % [resource_type, resource_key, full_path])

## 获取资源路径
func get_resource_path(resource_type: String, resource_key: String) -> String:
	if not _resource_registry.has(resource_type):
		push_error("请求的资源类型不存在: %s" % resource_type)
		return ""   
	if not _resource_registry[resource_type].has(resource_key):
		push_error("资源键 '%s' 在类型 '%s' 中不存在" % [resource_key, resource_type])
		return ""
	return _resource_registry[resource_type][resource_key]

## 获取资源路径并预加载
func load_resource(resource_type: String, resource_key: String) -> Resource:
	var path = get_resource_path(resource_type, resource_key)
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
	emit_signal("resource_packs_reloaded")

func _load_config(path: String) -> ConfigFile:
	var config = ConfigFile.new()
	var err = config.load(path)
	if err != OK:
		push_error("Config load failed: %s (err %d)" % [path, err])
		return null
	return config
