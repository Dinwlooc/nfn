## 管理渲染区域的生命周期、注册表与回调。
extends RefCounted
class_name RenderAreaManager

## 公共区域固定玩家ID
const PUBLIC_PLAYER_ID: int = RenderContext.PUBLIC_PLAYER_ID
## 渲染区域注册表：player_id -> { area_name -> RenderArea }
var render_areas: Dictionary[int, Dictionary] = {}
## 区域创建回调表：player_id -> { area_name -> Dictionary[Callable, bool] }（使用字典模拟HashSet）
var callback_map: Dictionary[int, Dictionary] = {}

## 当区域注册成功时发出
signal render_area_registered(area_name: StringName, area: RenderArea, player_id: int)
## 当区域注销时发出
signal render_area_unregistered(area_name: StringName, player_id: int)
## 当通过 create_render_area 新创建区域时发出
signal area_created(area: RenderArea, player_id: int)

var local_player_id: int = 0

func _init(p_local_player_id: int = 0) -> void:
	local_player_id = p_local_player_id
	render_area_registered.connect(_on_area_registered)

func _on_area_registered(area_name: StringName, area: RenderArea, player_id: int) -> void:
	var player_callbacks: Dictionary = callback_map.get(player_id,{})
	if not player_callbacks:
		return
	var area_callbacks: Dictionary = player_callbacks.get(area_name,{})
	if not area_callbacks:
		return
	var callbacks = area_callbacks.keys()
	for cb in callbacks:
		cb.call(area)

func _get_actual_player_id(player_id: int) -> int:
	if local_player_id == 0:
		return player_id
	if player_id == local_player_id:
		return PUBLIC_PLAYER_ID
	return player_id
## 注册区域创建回调
func connect_renderarea(area_name: StringName, callback: Callable, player_id: int = PUBLIC_PLAYER_ID) -> void:
	var actual_id = _get_actual_player_id(player_id)
	if render_areas.has(actual_id) and render_areas[actual_id].has(area_name):
		callback.call(render_areas[actual_id][area_name])
	if not callback_map.has(actual_id):
		callback_map[actual_id] = {}
	var player_dict: Dictionary = callback_map[actual_id]
	if not player_dict.has(area_name):
		player_dict[area_name] = {}
	var area_dict: Dictionary = player_dict[area_name]
	area_dict[callback] = true

## 移除回调
func disconnect_renderarea(area_name: StringName, callback: Callable, player_id: int = PUBLIC_PLAYER_ID) -> void:
	var actual_id = _get_actual_player_id(player_id)
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

## 注册区域实例
func register_render_area(area: RenderArea, player_id: int = PUBLIC_PLAYER_ID) -> void:
	var default_id = _get_actual_player_id(player_id)
	var area_name = area.get_area_name()
	if not render_areas.has(default_id) or not render_areas[default_id].has(area_name):
		if not render_areas.has(default_id):
			render_areas[default_id] = {}
		render_areas[default_id][area_name] = area
		render_area_registered.emit(area_name, area, player_id)
		return
	if default_id == PUBLIC_PLAYER_ID and player_id != PUBLIC_PLAYER_ID:
		var alt_id = player_id
		if not render_areas.has(alt_id) or not render_areas[alt_id].has(area_name):
			if not render_areas.has(alt_id):
				render_areas[alt_id] = {}
			render_areas[alt_id][area_name] = area
			render_area_registered.emit(area_name, area, player_id)
			return
	push_error("Duplicate area registration: ", area_name, " for player ", player_id)

## 注销区域（仅从注册表移除）
func unregister_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> bool:
	var actual_id = _get_actual_player_id(player_id)
	if render_areas.has(actual_id) and render_areas[actual_id].erase(area_name):
		render_area_unregistered.emit(area_name, player_id)
		if render_areas[actual_id].is_empty():
			render_areas.erase(actual_id)
		return true
	return false

## 获取区域实例
func get_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> RenderArea:
	var actual_id = _get_actual_player_id(player_id)
	if render_areas.has(actual_id):
		return render_areas[actual_id].get(area_name)
	return null

## 获取所有已注册玩家ID
func get_all_player_ids() -> Array[int]:
	return render_areas.keys()

## 获取指定玩家的所有区域（字典副本）
func get_player_areas(player_id: int = PUBLIC_PLAYER_ID) -> Dictionary[StringName, RenderArea]:
	var actual_id = _get_actual_player_id(player_id)
	return render_areas.get(actual_id, {}).duplicate()

## 创建并注册新区域（工厂方法）
func create_render_area(area_name: StringName, player_id: int = PUBLIC_PLAYER_ID) -> RenderArea:
	var area = RenderAreaFactory.create_area(area_name, player_id)
	if not area:
		return null
	register_render_area(area, player_id)
	area_created.emit(area, player_id)
	return area
