## 中央文本管理器：按玩家与区域缓存各路生成器给出的文本，并向显示端广播。
## 条目不因新增而丢弃，显示端可随时取全量结构，供后续多样式表现使用。
extends RefCounted
class_name CenterTextManager

## 游戏提示生成器脚本
const GameHintProviderScript = preload("res://core/Class/Render/Text/GameHintProvider.gd")
#==signals==
## 文本条目变化广播
## @emitter
signal entries_changed()

#==vars==
## 文本条目缓存：player_id -> { area_name -> { provider_id, text } }
var text_entries: Dictionary[int, Dictionary] = {}
## 已登记的生成器
var providers: Array[CenterTextProvider] = []

#==public==
## 登记生成器
## @side_effect
func register_provider(provider: CenterTextProvider) -> void:
	providers.append(provider)

## 建立默认生成器并把上下文交给全部生成器
## @side_effect
func setup_defaults(context: RenderContext) -> void:
	register_provider(GameHintProviderScript.new())
	for provider in providers:
		provider.setup(context)

## 写入一路文本
## @side_effect
func push_text(area_name: StringName, player_id: int, provider_id: int, text: String) -> void:
	if not text_entries.has(player_id):
		text_entries[player_id] = {}
	var area_entries: Dictionary = text_entries[player_id]
	area_entries[area_name] = {"provider_id": provider_id, "text": text}
	entries_changed.emit()

## 清空一路文本：只清本生成器写入的条目
## @side_effect
func clear_text(area_name: StringName, player_id: int, provider_id: int) -> void:
	if not text_entries.has(player_id):
		return
	var area_entries: Dictionary = text_entries[player_id]
	if not area_entries.has(area_name):
		return
	var entry: Dictionary = area_entries[area_name]
	if int(entry.get("provider_id", -1)) != provider_id:
		return
	area_entries.erase(area_name)
	entries_changed.emit()

## 取某玩家某区域的文本；无条目返回空串
## @pure
func get_text(area_name: StringName, player_id: int) -> String:
	if not text_entries.has(player_id):
		return ""
	var area_entries: Dictionary = text_entries[player_id]
	if not area_entries.has(area_name):
		return ""
	return String(area_entries[area_name].get("text", ""))

## 取当前最早的条文本；无条目返回空串
## @pure
func get_first_text() -> String:
	for player_id in text_entries:
		var area_entries: Dictionary = text_entries[player_id]
		for area_name in area_entries:
			var text_value: String = String(area_entries[area_name].get("text", ""))
			if not text_value.is_empty():
				return text_value
	return ""
