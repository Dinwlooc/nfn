## 管理渲染区域的生命周期、注册表与回调。
## 支持区域替换，回调签名改为 (new_area: RenderArea, old_area: RenderArea)。
extends RefCounted
class_name RenderAreaManager

const PUBLIC_PLAYER_ID: int = RenderContext.PUBLIC_PLAYER_ID
## 渲染区域注册表：player_id -> { area_name -> RenderArea }
var render_areas: Dictionary[int, Dictionary] = {}
## 区域创建回调表：player_id -> { area_name -> Dictionary[Callable, bool] }
var callback_map: Dictionary[int, Dictionary] = {}

signal render_area_registered(area_name: StringName, area: RenderArea, player_id: int)
signal render_area_unregistered(area_name: StringName, player_id: int)
signal area_created(area: RenderArea, player_id: int)

var local_player_id: int = 0

func _init(p_local_player_id: int = 0) -> void:
	local_player_id = p_local_player_id

func _get_actual_player_id(player_id: int) -> int:
	if local_player_id == 0:
		return player_id
	if player_id == local_player_id:
		return PUBLIC_PLAYER_ID
	return player_id

## 注册区域创建/替换回调（回调签名：func(new_area: RenderArea, old_area: RenderArea)）
func connect_renderarea(area_name: StringName, callback: Callable, player_id: int = PUBLIC_PLAYER_ID) -> void:
	var actual_id: int = _get_actual_player_id(player_id)
	if render_areas.has(actual_id) and render_areas[actual_id].has(area_name):
		callback.call(render_areas[actual_id][area_name], null)
	if not callback_map.has(actual_id):
		callback_map[actual_id] = {}
	var player_dict: Dictionary = callback_map[actual_id]
	if not player_dict.has(area_name):
		player_dict[area_name] = {}
	var area_dict: Dictionary = player_dict[area_name]
	area_dict[callback] = true

## 移除回调
func disconnect_renderarea(area_name: StringName, callback: Callable, player_id: int = PUBLIC_PLAYER_ID) -> void:
	var actual_id: int = _get_actual_player_id(player_id)
	if not callback_map.has(actual_id):
		return
	var player_dict: Dictionary = callback_map[actual_id]
	if not player_dict.has(area_name):
		return
	var area_dict: Dictionary = player_dict[area_name]
	area_dict.erase(callback)
	if area_dict.is_empty():
		player_dict.erase(area_name)
		if player_dict.is_empty():
			callback_map.erase(actual_id)

## 注册区域实例（支持替换，触发回调传递新旧）
func register_render_area(area: RenderArea, player_id: int = PUBLIC_PLAYER_ID) -> void:
	var actual_id: int = _get_actual_player_id(player_id)
	var area_name: StringName = area.get_area_name()
	var old_area: RenderArea = null
	if render_areas.has(actual_id) and render_areas[actual_id].has(area_name):
		old_area = render_areas[actual_id][area_name]
		if old_area == area:
			return
	if not render_areas.has(actual_id):
		render_areas[actual_id] = {}
	render_areas[actual_id][area_name] = area
	render_area_registered.emit(area_name, area, player_id)
	_emit_callbacks(actual_id, area_name, area, old_area)

## 注销区域
func unregister_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> bool:
	var actual_id: int = _get_actual_player_id(player_id)
	if render_areas.has(actual_id) and render_areas[actual_id].erase(area_name):
		render_area_unregistered.emit(area_name, player_id)
		if render_areas[actual_id].is_empty():
			render_areas.erase(actual_id)
		return true
	return false

## 获取区域实例
func get_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> RenderArea:
	var actual_id: int = _get_actual_player_id(player_id)
	if render_areas.has(actual_id):
		return render_areas[actual_id].get(area_name)
	return null

## 获取所有已注册玩家ID
func get_all_player_ids() -> Array[int]:
	var keys: Array[int] = render_areas.keys()
	return keys

## 获取指定玩家的所有区域（字典副本）
func get_player_areas(player_id: int = PUBLIC_PLAYER_ID) -> Dictionary[StringName, RenderArea]:
	var actual_id: int = _get_actual_player_id(player_id)
	var areas: Dictionary = render_areas.get(actual_id, {})
	return areas.duplicate()

## 创建并注册新区域
func create_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> RenderArea:
	var area: RenderArea = RenderAreaFactory.create_area(area_name, player_id)
	if not area:
		return null
	register_render_area(area, player_id)
	area_created.emit(area, player_id)
	return area

## 触发指定区域的所有回调（内部使用）
func _emit_callbacks(player_id: int, area_name: StringName, new_area: RenderArea, old_area: RenderArea) -> void:
	if not callback_map.has(player_id):
		return
	var player_dict: Dictionary = callback_map[player_id]
	if not player_dict.has(area_name):
		return
	var area_dict: Dictionary = player_dict[area_name]
	for cb: Callable in area_dict.keys():
		cb.call(new_area, old_area)
