## 全局配置：资源包加载、配置表、翻译查表与卡表展开。
extends Node

const ConfigTableScript := preload("res://core/Class/Config/ConfigTable.gd")
const ConfigTableLoaderScript := preload("res://core/Class/Config/ConfigTableLoader.gd")
## 系统端配置根目录（本地基线）
const SYSTEM_CONFIG_ROOT: String = "res://config/system"
## 渲染端配置根目录（本地基线）
const RENDER_CONFIG_ROOT: String = "res://config/render"
## 系统端用户目录根（叠加在本地根之上，后加载覆盖）
const USER_SYSTEM_CONFIG_ROOT: String = "user://config/system"
## 渲染端用户目录根
const USER_RENDER_CONFIG_ROOT: String = "user://config/render"
## 资源包清单路径（tier-0 引导文件，不进配置表加载器）
const PACKS_CONFIG_PATH: String = "res://config/packs.cfg"
## 配置表引导开关路径（tier-0）
const BOOTSTRAP_CONFIG_PATH: String = "res://config/bootstrap.cfg"
## 卡表活动预设的内置回落值（cfg 未声明 [active] 时使用）
const DEFAULT_CARDS_PRESET: StringName = &"nfn:default"

#=== Variables ===
## 内嵌资源包清单：分组名 → 包名数组；packs.cfg 缺失时回落
var _debug_packs: Dictionary[StringName, Variant] = {
	&"official": ["default"],
	&"mods": []
}
## 资源包加载器，_ready 时创建
var _loader: ResourcePackLoader
## 配置表加载器，_ready 时创建
var _config_loader: ConfigTableLoaderScript
## 系统端配置表：表名 → 表
var _system_tables: Dictionary[StringName, ConfigTableScript] = {}
## 渲染端配置表：表名 → 表
var _render_tables: Dictionary[StringName, ConfigTableScript] = {}

#=== Signals ===
## 资源包重载完成
## @emitter
signal resource_packs_reloaded
## 配置表重载完成
## @emitter
signal config_tables_reloaded

#=== Public Methods ===
## 创建加载器、连接完成信号并加载全部资源包与配置表
## @override
func _ready() -> void:
	_loader = ResourcePackLoader.new()
	_loader.all_packs_loaded.connect(_on_all_packs_loaded)
	_config_loader = ConfigTableLoaderScript.new()
	load_all_resource_packs()
	reload_config_tables()

## 加载分组资源包；未传分组时读 packs.cfg，清单缺失则用内嵌默认
## @delegates
func load_all_resource_packs(packs: Dictionary = {}) -> void:
	var groups: Dictionary = packs if not packs.is_empty() else _read_packs_manifest()
	_loader.load_all(groups)

## 取指定端的配置表；表未加载时返回 null
## @nullable_pure
func get_config_table(scope: StringName, table_name: StringName) -> ConfigTableScript:
	return _tables_of(scope).get(table_name)

## 取某端已加载的表名（实验室与模组自测用；不限制表的种类）
## @pure
func get_config_table_names(scope: StringName) -> Array[StringName]:
	var names: Array[StringName] = []
	for table_name: StringName in _tables_of(scope):
		names.append(table_name)
	return names

## 重载两端配置表并广播
## @delegates
func reload_config_tables() -> void:
	_system_tables = _config_loader.load_scope(_config_roots(SYSTEM_CONFIG_ROOT, USER_SYSTEM_CONFIG_ROOT))
	_render_tables = _config_loader.load_scope(_config_roots(RENDER_CONFIG_ROOT, USER_RENDER_CONFIG_ROOT))
	config_tables_reloaded.emit()

## 取翻译文本；资源缺失时原样返回键
func get_translation(key: StringName, lang: StringName = &"Zh_CN") -> String:
	var resource = load_resource(&"translation", lang)
	return resource.get_message(key) if resource else String(key)

## 按卡表预设展开卡牌模板路径；值为每种花色的张数
## @delegates
func get_cards_list(preset_id: StringName = &"") -> PackedStringArray:
	var table: ConfigTableScript = get_config_table(&"system", &"cards")
	if not table:
		push_error("卡表缺失：%s/cards.cfg" % SYSTEM_CONFIG_ROOT)
		return []
	var active: StringName = preset_id if preset_id != &"" else _active_cards_preset(table)
	return _expand_preset(table.get_section(StringName("preset:%s" % active)), active)

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

#=== Private Methods ===
## 读资源包清单；缺失时回落内嵌默认
## @pure
func _read_packs_manifest() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(PACKS_CONFIG_PATH) != OK:
		push_warning("资源包清单缺失，回落内嵌默认：%s" % PACKS_CONFIG_PATH)
		return _debug_packs
	var groups: Dictionary = {}
	for section: String in config.get_sections():
		groups[StringName(section)] = config.get_value(section, "packs", [])
	return groups if not groups.is_empty() else _debug_packs

## 组装某端的根目录序列：本地基线在前，启用用户层时叠加在后
## @pure
func _config_roots(local_root: String, user_root: String) -> Array[String]:
	var roots: Array[String] = [local_root]
	if _read_use_user_config():
		roots.append(user_root)
	return roots

## 读引导开关；缺失时只用本地根
## @pure
func _read_use_user_config() -> bool:
	var config := ConfigFile.new()
	if config.load(BOOTSTRAP_CONFIG_PATH) != OK:
		return false
	return bool(config.get_value("config_paths", "use_user_config", false))

## 读卡表活动预设标识；cfg 未声明时回落内置常量
## @pure
func _active_cards_preset(table: ConfigTableScript) -> StringName:
	return StringName(table.get_value(&"active", &"preset", DEFAULT_CARDS_PRESET))

## 把预设段展开为模板路径列表；缺登记键报错并跳过
## @pure
func _expand_preset(rows: Dictionary, preset: StringName) -> PackedStringArray:
	if rows.is_empty():
		push_error("卡表预设为空：preset:%s" % preset)
		return []
	var cards_list: PackedStringArray = []
	for card_key: StringName in rows:
		var card_path := get_resource_path(&"cards", card_key)
		if card_path.is_empty():
			push_error("卡牌模板未在资源包登记：%s（预设 preset:%s）" % [card_key, preset])
			continue
		for i in range(int(rows[card_key])):
			cards_list.append(card_path)
	return cards_list

## 取某端的表集合
## @pure
func _tables_of(scope: StringName) -> Dictionary[StringName, ConfigTableScript]:
	match scope:
		&"system":
			return _system_tables
		&"render":
			return _render_tables
	return {}

## 资源包加载完成回调，转发为公开信号
## @emitter
func _on_all_packs_loaded() -> void:
	resource_packs_reloaded.emit()
