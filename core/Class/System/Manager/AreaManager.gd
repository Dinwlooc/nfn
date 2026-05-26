## 区域注册表统一管理器，管理所有公共区域与玩家私有区域。
extends RefCounted
class_name AreaManager

## 双层字典：player_id -> { area_name : Area }
var _areas: Dictionary[int, Dictionary] = {}
## 公共区域使用的玩家 ID
const PUBLIC_PLAYER_ID: int = GameState.PUBLIC_PLAYER_ID
# 信号
signal area_added(area: Area)
signal area_removed(area: Area)

func _init() -> void:
	_init_public_areas()

## 初始化公共区域（应在 GameState 初始化时调用一次）
func _init_public_areas() -> void:
	_ensure_player_dict(PUBLIC_PLAYER_ID)
	var public_areas: Dictionary = _areas[PUBLIC_PLAYER_ID]
	# 中央区
	if not public_areas.has(GlobalConstants.DefaultArea.CENTER):
		var center := AreaCenter.new()
		public_areas[GlobalConstants.DefaultArea.CENTER] = center
		area_added.emit(center)
	# 牌堆区
	if not public_areas.has(GlobalConstants.DefaultArea.DRAWING):
		var drawing := AreaDrawing.new()
		public_areas[GlobalConstants.DefaultArea.DRAWING] = drawing
		area_added.emit(drawing)
	# 弃牌堆区
	if not public_areas.has(GlobalConstants.DefaultArea.DISCARD):
		var discard := AreaDiscard.new()
		public_areas[GlobalConstants.DefaultArea.DISCARD] = discard
		area_added.emit(discard)

## 确保某个玩家的区域字典存在
func _ensure_player_dict(player_id: int) -> void:
	if not _areas.has(player_id):
		_areas[player_id] = {}

## 为新玩家创建所有私有区域实例
func create_areas_for_player(player: Player) -> void:
	var pid: int = player.get_id()
	_ensure_player_dict(pid)
	var player_areas: Dictionary = _areas[pid]
	if not player_areas.has(GlobalConstants.DefaultArea.HAND):
		var hand := AreaHand.new(player)
		player_areas[GlobalConstants.DefaultArea.HAND] = hand
		area_added.emit(hand)
	if not player_areas.has(GlobalConstants.DefaultArea.DEFENCE):
		var defense := AreaDefence.new(player)
		player_areas[GlobalConstants.DefaultArea.DEFENCE] = defense
		area_added.emit(defense)
	if not player_areas.has(GlobalConstants.DefaultArea.ABILITY):
		var ability := AreaAbility.new(player)
		player_areas[GlobalConstants.DefaultArea.ABILITY] = ability
		area_added.emit(ability)

## 移除指定玩家的所有区域并发出移除信号
func remove_areas_for_player(player_id: int) -> void:
	if not _areas.has(player_id):
		return
	var player_areas: Dictionary = _areas[player_id]
	for area_name in player_areas.keys():
		area_removed.emit(get_area(player_id,area_name))
	_areas.erase(player_id)

## 获取指定玩家、指定名称的区域
func get_area(player_id: int, area_name: StringName) -> Area:
	if not _areas.has(player_id):
		return null
	return _areas[player_id].get(area_name)

## 设置（添加或替换）指定玩家、指定名称的区域
func set_area(player_id: int, area_name: StringName, area: Area) -> void:
	_ensure_player_dict(player_id)
	var old_area: Area = _areas[player_id].get(area_name)
	_areas[player_id][area_name] = area
	if old_area:
		area_removed.emit(old_area)
	area_added.emit(area)

## 获取手牌区域（便捷方法）
func get_hand_area(player_id: int) -> AreaHand:
	return get_area(player_id, GlobalConstants.DefaultArea.HAND)

## 获取守备区域（便捷方法）
func get_defense_area(player_id: int) -> AreaDefence:
	return get_area(player_id, GlobalConstants.DefaultArea.DEFENCE)

## 获取技能区域（便捷方法）
func get_ability_area(player_id: int) -> AreaAbility:
	return get_area(player_id, GlobalConstants.DefaultArea.ABILITY)

## 获取公共中央区
func get_center_area() -> AreaCenter:
	return get_area(PUBLIC_PLAYER_ID, GlobalConstants.DefaultArea.CENTER)

## 获取公共牌堆区
func get_drawing_area() -> AreaDrawing:
	return get_area(PUBLIC_PLAYER_ID, GlobalConstants.DefaultArea.DRAWING)

## 获取公共弃牌堆区
func get_discard_area() -> AreaDiscard:
	return get_area(PUBLIC_PLAYER_ID, GlobalConstants.DefaultArea.DISCARD)
