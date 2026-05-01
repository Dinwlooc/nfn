## 区域注册表纯数据容器，仅提供区域字典的创建、销毁与查询。
## 不持有 [GameState] 引用，不连接业务信号。区域增删通过信号通知。
extends RefCounted
class_name AreaManager

signal hand_area_added(area: AreaHand, player_id: int)
signal defense_area_added(area: AreaDefence, player_id: int)
signal ability_area_added(area: AreaAbility, player_id: int)
signal hand_area_removed(player_id: int)
signal defense_area_removed(player_id: int)
signal ability_area_removed(player_id: int)

var _hands: Dictionary[int, AreaHand] = {}
var _defenses: Dictionary[int, AreaDefence] = {}
var _abilities: Dictionary[int, AreaAbility] = {}

## 为新玩家创建所有区域实例并发出添加信号
func create_areas_for_player(player: Player) -> void:
	var pid: int = player.player_id
	if _hands.has(pid):
		return
	_hands[pid] = AreaHand.new(player)
	_defenses[pid] = AreaDefence.new(player)
	_abilities[pid] = AreaAbility.new(player)
	hand_area_added.emit(_hands[pid], pid)
	defense_area_added.emit(_defenses[pid], pid)
	ability_area_added.emit(_abilities[pid], pid)

## 移除指定玩家的所有区域并发出移除信号
func remove_areas_for_player(player_id: int) -> void:
	if _hands.erase(player_id):
		hand_area_removed.emit(player_id)
	if _defenses.erase(player_id):
		defense_area_removed.emit(player_id)
	if _abilities.erase(player_id):
		ability_area_removed.emit(player_id)

## 获取手牌区域
func get_hand_area(player_id: int) -> AreaHand:
	return _hands.get(player_id)

## 获取守备区域
func get_defense_area(player_id: int) -> AreaDefence:
	return _defenses.get(player_id)

## 获取技能区域
func get_ability_area(player_id: int) -> AreaAbility:
	return _abilities.get(player_id)

func get_area(area_name:StringName,player_id:int)->Area:
	match area_name:
		GlobalConstants.DefaultArea.HAND:
			return get_hand_area(player_id)
		GlobalConstants.DefaultArea.DEFENCE:
			return get_defense_area(player_id)
	return null
