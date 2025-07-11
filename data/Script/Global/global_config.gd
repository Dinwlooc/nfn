extends Node

var resource_type_registry = [
	"cards",       
	"card_main_icon",  
	"cardface",   
]#渲染层需求的资源类型。自定义渲染层应该注册自己需要的资源类型。
var _debug_packs: Dictionary = {
	"official": ["default"],
	"mods": []
}
var _resource_registry: Dictionary = {}
signal resource_packs_reloaded

func _ready() -> void:
	# 初始化时加载所有资源包
	load_all_resource_packs()
	

func get_cards_list(list_name:String = "default")->Array[String]:
	var config = ConfigFile.new()
	var config_path = "res://cards_load_list.cfg"
	var err = config.load("res://cards_load_list.cfg")
	if err != OK:
		push_error("未找到配置: %s (错误码: %d)" % [config_path, err])
		return []
	var cards_array:Array[String]
	for card_name in config.get_section_keys(list_name):
		for i in range(config.get_value(list_name, card_name)):
			cards_array.append(_resource_registry["cards"][card_name])
	return cards_array as Array[String]
	
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
	var config = ConfigFile.new()
	var err = config.load(config_path)
	if err != OK:
		push_error("加载资源包配置失败: %s (错误码: %d)" % [config_path, err])
		return
	# 处理所有资源类型部分
	for resource_type in config.get_sections():
		# 跳过特殊部分
		if not resource_type in resource_type_registry:
			_resource_registry[resource_type] = {}
			continue
		if not _resource_registry.has(resource_type):
			_resource_registry[resource_type] = {}
		# 处理当前资源类型的所有键值对
		for resource_key in config.get_section_keys(resource_type):
			var relative_path = config.get_value(resource_type, resource_key)
			var full_path = "%s/%s" % [pack_path, relative_path]
			_resource_registry[resource_type][resource_key] = full_path
			print("加载资源: [%s] %s -> %s" % [resource_type, resource_key, full_path])

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
