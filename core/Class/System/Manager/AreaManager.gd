## 区域注册表统一管理器，管理所有公共区域与玩家私有区域。
extends RefCounted
class_name AreaManager

#== Variables ==
## 双层字典：player_id -> { area_name : Area }
var _areas: Dictionary[int, Dictionary] = {}

#== Constants ==
## 公共区域使用的玩家 ID
const PUBLIC_PLAYER_ID: int = GameState.PUBLIC_PLAYER_ID

#== Signals ==
## 区域添加信号
## @emitter
signal area_added(area: Area)
## 区域移除信号
## @emitter
signal area_removed(area: Area)

#== Constructor ==
## 构造函数：初始化公共区域
## @endo
func _init() -> void:
	_init_public_areas()

#== Public Methods ==
## 为新玩家创建所有私有区域实例
## @endo @emitter
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
## @endo @emitter
func remove_areas_for_player(player_id: int) -> void:
	if not _areas.has(player_id):
		return
	var player_areas: Dictionary = _areas[player_id]
	for area in player_areas.values():  # 优化：直接遍历值，避免二次查找
		area_removed.emit(area)
	_areas.erase(player_id)
## 获取指定玩家、指定名称的区域
## @semi-pure
func get_area(player_id: int, area_name: StringName) -> Area:
	return _areas[player_id].get(area_name,null)
## 设置（添加或替换）指定玩家、指定名称的区域
## @endo @emitter
func set_area(player_id: int, area_name: StringName, area: Area) -> void:
	_ensure_player_dict(player_id)
	var old_area: Area = _areas[player_id].get(area_name)
	_areas[player_id][area_name] = area
	if old_area:
		area_removed.emit(old_area)
	area_added.emit(area)
## 获取指定玩家的所有区域名称列表
## @pure
func get_area_names_for_player(player_id: int) -> Array[StringName]:
	if not _areas.has(player_id):
		return []
	return _areas[player_id].keys()
## 获取手牌区域（便捷方法）
## @facade @semi-pure。
func get_hand_area(player_id: int) -> AreaHand:
	return get_area(player_id, GlobalConstants.DefaultArea.HAND)
## 获取守备区域（便捷方法）
## @facade @semi-pure。
func get_defense_area(player_id: int) -> AreaDefence:
	return get_area(player_id, GlobalConstants.DefaultArea.DEFENCE)
## 获取技能区域（便捷方法）
## @facade @semi-pure。
func get_ability_area(player_id: int) -> AreaAbility:
	return get_area(player_id, GlobalConstants.DefaultArea.ABILITY)
## 获取公共中央区
## @facade @semi-pure。
func get_center_area() -> AreaCenter:
	return get_area(PUBLIC_PLAYER_ID, GlobalConstants.DefaultArea.CENTER)
## 获取公共牌堆区
## @facade @semi-pure。
func get_drawing_area() -> AreaDrawing:
	return get_area(PUBLIC_PLAYER_ID, GlobalConstants.DefaultArea.DRAWING)
## 获取公共弃牌堆区
## @facade @semi-pure。
func get_discard_area() -> AreaDiscard:
	return get_area(PUBLIC_PLAYER_ID, GlobalConstants.DefaultArea.DISCARD)

#== Private Methods ==
## 初始化公共区域
## @endo @emitter
func _init_public_areas() -> void:
	_ensure_player_dict(PUBLIC_PLAYER_ID)
	var public_areas: Dictionary = _areas[PUBLIC_PLAYER_ID]
	if not public_areas.has(GlobalConstants.DefaultArea.CENTER):
		var center := AreaCenter.new()
		public_areas[GlobalConstants.DefaultArea.CENTER] = center
		area_added.emit(center)
	if not public_areas.has(GlobalConstants.DefaultArea.DRAWING):
		var drawing := AreaDrawing.new()
		public_areas[GlobalConstants.DefaultArea.DRAWING] = drawing
		area_added.emit(drawing)
	if not public_areas.has(GlobalConstants.DefaultArea.DISCARD):
		var discard := AreaDiscard.new()
		public_areas[GlobalConstants.DefaultArea.DISCARD] = discard
		area_added.emit(discard)
## 确保某个玩家的区域字典存在。
func _ensure_player_dict(player_id: int) -> void:
	if not _areas.has(player_id):
		_areas[player_id] = {}
